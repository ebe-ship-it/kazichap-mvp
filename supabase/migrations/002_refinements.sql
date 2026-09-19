-- Apply after 001_init.sql. For a NEW project, run supabase/bootstrap.sql instead.
-- Transactional, preserves existing accounts and jobs. Do not run 001 again.
begin;

-- An hourly rate is not a final bill. Both parties must agree on billed minutes.
alter table public.engagements add column if not exists billable_minutes integer;
alter table public.engagements add column if not exists time_approved boolean not null default false;
alter table public.engagements add column if not exists total_amount_tzs numeric(14,2)
  generated always as (case when pricing_type='fixed' then agreed_amount_tzs
    when billable_minutes is not null then round(agreed_amount_tzs*billable_minutes/60,2) else null end) stored;

create or replace function public.valid_coordinates(p_lat double precision,p_lng double precision)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_lat between -90 and 90 and p_lng between -180 and 180,false);
$$;
create or replace function public.valid_category(p_category text)
returns boolean language sql immutable set search_path='' as $$
 select coalesce(p_category = any(array['Plumber','Electrician','Carpenter','Painter','Cleaner','Chef','Tutor','Relief Teacher','Nurse','Doctor','Mechanic','Delivery / Errands','Other']),false);
$$;

-- These constraints validate new writes without destroying historical records.
do $$ begin
 if not exists(select 1 from pg_constraint where conname='kzc_profile_inputs' and conrelid='public.profiles'::regclass) then
  alter table public.profiles add constraint kzc_profile_inputs check (
    char_length(trim(full_name)) between 2 and 100 and (bio is null or char_length(bio)<=1000)
    and (area is null or char_length(area)<=120)
    and ((lat is null and lng is null) or public.valid_coordinates(lat,lng))
    and (role='customer' or (public.valid_category(service_category) and hourly_rate_tzs between 1 and 100000000))
  ) not valid;
 end if;
 if not exists(select 1 from pg_constraint where conname='kzc_job_inputs' and conrelid='public.jobs'::regclass) then
  alter table public.jobs add constraint kzc_job_inputs check (
   char_length(trim(title)) between 3 and 120 and char_length(trim(description)) between 10 and 4000
   and public.valid_category(service_category) and amount_tzs between 1 and 100000000
   and public.valid_coordinates(lat,lng)) not valid;
 end if;
 if not exists(select 1 from pg_constraint where conname='kzc_engagement_inputs' and conrelid='public.engagements'::regclass) then
  alter table public.engagements add constraint kzc_engagement_inputs check (
   customer_id<>provider_id and agreed_amount_tzs between 1 and 100000000
   and (billable_minutes is null or billable_minutes between 1 and 43200)) not valid;
 end if;
 if not exists(select 1 from pg_constraint where conname='kzc_application_inputs' and conrelid='public.applications'::regclass) then
  alter table public.applications add constraint kzc_application_inputs check (
    (note is null or char_length(note)<=1000) and (proposed_rate_tzs is null or proposed_rate_tzs between 1 and 100000000)) not valid;
 end if;
 if not exists(select 1 from pg_constraint where conname='kzc_review_inputs' and conrelid='public.reviews'::regclass) then
  alter table public.reviews add constraint kzc_review_inputs check (comment is null or char_length(comment)<=2000) not valid;
 end if;
end $$;

-- Close direct insert bypasses. State transitions happen only through checked RPCs.
drop policy if exists "customers insert own jobs" on public.jobs;
drop policy if exists "providers apply as self" on public.applications;
drop policy if exists "reviews readable" on public.reviews;
drop policy if exists "review participants read" on public.reviews;
create policy "review participants read" on public.reviews for select to authenticated using(customer_id=auth.uid() or provider_id=auth.uid());
drop policy if exists "match participants read locations" on public.engagement_locations;
create policy "match participants read locations" on public.engagement_locations for select to authenticated using(exists(
 select 1 from public.engagements e where e.id=engagement_id and e.status in ('accepted','in_progress')
 and (e.customer_id=auth.uid() or e.provider_id=auth.uid())));

-- Explicit privileges, independent of the project's default table/function grants.
revoke all on table public.profiles,public.private_contacts,public.jobs,public.applications,public.engagements,
 public.conversations,public.messages,public.engagement_locations,public.reviews from public,anon,authenticated;
-- Original column grants survive REVOKE at table level, so revoke them separately.
revoke select(id,full_name,role,service_category,hourly_rate_tzs,bio,is_online,is_verified,verification_status,rating_avg,review_count,created_at,updated_at) on public.profiles from public,anon,authenticated;
revoke select(id,customer_id,title,description,service_category,pricing_type,amount_tzs,status,created_at,updated_at) on public.jobs from public,anon,authenticated;
grant select(id,full_name,role,service_category,hourly_rate_tzs,bio,is_online,is_verified,verification_status,rating_avg,review_count,created_at,updated_at) on public.profiles to authenticated;
grant select(id,customer_id,title,description,service_category,pricing_type,amount_tzs,status,created_at,updated_at) on public.jobs to authenticated;
grant select on public.private_contacts,public.applications,public.engagements,public.conversations,public.messages,public.engagement_locations,public.reviews to authenticated;
grant insert(conversation_id,sender_id,body) on public.messages to authenticated;

create or replace function public.set_my_location(p_lat double precision,p_lng double precision,p_area text default null)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 if not public.valid_coordinates(p_lat,p_lng) then raise exception 'Invalid coordinates'; end if;
 if char_length(p_area)>120 then raise exception 'Area is too long'; end if;
 update public.profiles set lat=p_lat,lng=p_lng,location=extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography,
 area=nullif(trim(p_area),''),updated_at=now() where id=auth.uid();
 if not found then raise exception 'Profile not found'; end if;
end $$;

create or replace function public.set_online(p_online boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
 update public.profiles set is_online=p_online,updated_at=now() where id=auth.uid() and role='provider'
 and (not p_online or (location is not null and (service_category not in ('Doctor','Nurse') or is_verified)));
 if not found then raise exception 'Add your location first. Doctors and nurses also need administrator verification before going online.'; end if;
end $$;

create or replace function public.get_nearby_providers(p_lat double precision,p_lng double precision,p_category text,p_radius_meters double precision default 15000)
returns table(id uuid,full_name text,service_category text,hourly_rate_tzs numeric,dist_meters double precision,is_verified boolean,rating_avg numeric,review_count integer,bio text)
language sql stable security definer set search_path=public,extensions as $$
 select p.id,p.full_name,p.service_category,p.hourly_rate_tzs,
 (round(extensions.st_distance(p.location,me.location)/500)*500)::double precision,
 p.is_verified,p.rating_avg,p.review_count,p.bio
 from public.profiles p join public.profiles me on me.id=auth.uid() and me.role='customer' and me.location is not null
 where p.role='provider' and p.is_online and p.location is not null and p.service_category=p_category
 and (p.service_category not in ('Doctor','Nurse') or p.is_verified)
 and p_lat=me.lat and p_lng=me.lng
 and p_radius_meters between 1 and 20000
 and extensions.st_dwithin(p.location,me.location,p_radius_meters)
 order by p.location operator(extensions.<->) me.location limit 50;
$$;

create or replace function public.get_nearby_jobs(p_lat double precision,p_lng double precision,p_category text,p_radius_meters double precision default 20000)
returns table(id uuid,customer_id uuid,title text,description text,service_category text,pricing_type text,amount_tzs numeric,dist_meters double precision,created_at timestamptz)
language sql stable security definer set search_path=public,extensions as $$
 select j.id,j.customer_id,j.title,j.description,j.service_category,j.pricing_type,j.amount_tzs,
 (round(extensions.st_distance(j.location,me.location)/500)*500)::double precision,j.created_at
 from public.jobs j join public.profiles me on me.id=auth.uid() and me.role='provider' and me.location is not null
 where j.status='open' and j.service_category=p_category and me.service_category=p_category
 and (me.service_category not in ('Doctor','Nurse') or me.is_verified)
 and p_lat=me.lat and p_lng=me.lng and p_radius_meters between 1 and 20000
 and extensions.st_dwithin(j.location,me.location,p_radius_meters)
 order by j.location operator(extensions.<->) me.location limit 50;
$$;

create or replace function public.create_job(p_title text,p_description text,p_category text,p_pricing_type text,p_amount_tzs numeric,p_lat double precision,p_lng double precision)
returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid;
begin
 if not exists(select 1 from public.profiles where id=auth.uid() and role='customer') then raise exception 'Only customers can post jobs'; end if;
 if not public.valid_coordinates(p_lat,p_lng) then raise exception 'Invalid job location'; end if;
 if not public.valid_category(p_category) or p_pricing_type not in ('hourly','fixed') then raise exception 'Invalid category or pricing'; end if;
 insert into public.jobs(customer_id,title,description,service_category,pricing_type,amount_tzs,lat,lng,location)
 values(auth.uid(),trim(p_title),trim(p_description),p_category,p_pricing_type,p_amount_tzs,p_lat,p_lng,
 extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography) returning id into v_id;
 return v_id;
end $$;

create or replace function public.apply_to_job(p_job_id uuid,p_note text,p_rate numeric)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_job public.jobs%rowtype; v_id uuid;
begin
 select * into v_job from public.jobs where id=p_job_id for update;
 if not found or v_job.status<>'open' then raise exception 'This job is no longer open'; end if;
 if not exists(select 1 from public.profiles where id=auth.uid() and role='provider' and service_category=v_job.service_category
  and (service_category not in ('Doctor','Nurse') or is_verified)) then raise exception 'Your profile is not eligible for this job'; end if;
 if p_rate is null or p_rate not between 1 and 100000000 then raise exception 'Enter a valid proposed amount'; end if;
 insert into public.applications(job_id,provider_id,note,proposed_rate_tzs) values(p_job_id,auth.uid(),trim(p_note),p_rate)
 returning id into v_id;
 return v_id;
exception when unique_violation then raise exception 'You have already applied to this job';
end $$;

create or replace function public.start_direct_inquiry(p_provider_id uuid,p_message text default null)
returns table(engagement_id uuid,conversation_id uuid)
language plpgsql security definer set search_path=public as $$
declare v_eng uuid;v_conv uuid;v_rate numeric;
begin
 -- Lock customer to make repeated concurrent clicks reuse the same active inquiry.
 perform 1 from public.profiles where id=auth.uid() and role='customer' for update;
 if not found then raise exception 'Only customers can start an inquiry'; end if;
 select e.id,c.id into v_eng,v_conv from public.engagements e join public.conversations c on c.engagement_id=e.id
 where e.customer_id=auth.uid() and e.provider_id=p_provider_id and e.source_type='direct'
 and e.status in ('requested','accepted','in_progress','completed') order by e.created_at desc limit 1;
 if found then return query select v_eng,v_conv;return; end if;
 select hourly_rate_tzs into v_rate from public.profiles where id=p_provider_id and role='provider' and is_online
 and (service_category not in ('Doctor','Nurse') or is_verified) for share;
 if v_rate is null then raise exception 'Provider is unavailable or awaiting verification'; end if;
 insert into public.engagements(source_type,customer_id,provider_id,pricing_type,agreed_amount_tzs,status)
 values('direct',auth.uid(),p_provider_id,'hourly',v_rate,'requested') returning id into v_eng;
 insert into public.conversations(engagement_id,customer_id,provider_id) values(v_eng,auth.uid(),p_provider_id) returning id into v_conv;
 if nullif(trim(p_message),'') is not null then insert into public.messages(conversation_id,sender_id,body) values(v_conv,auth.uid(),trim(p_message)); end if;
 return query select v_eng,v_conv;
end $$;

create or replace function public.accept_application(p_application_id uuid)
returns table(engagement_id uuid,conversation_id uuid)
language plpgsql security definer set search_path=public as $$
declare v_app public.applications%rowtype;v_job public.jobs%rowtype;v_eng uuid;v_conv uuid;v_job_id uuid;
begin
 if auth.uid() is null then raise exception 'Sign in first'; end if;
 select job_id into v_job_id from public.applications where id=p_application_id;
 -- Consistent lock order: job first, then application (prevents competing-hire deadlocks).
 select * into v_job from public.jobs where id=v_job_id for update;
 if not found or v_job.customer_id is distinct from auth.uid() then raise exception 'Job not found or not yours'; end if;
 if v_job.status<>'open' then raise exception 'Job is no longer open'; end if;
 select * into v_app from public.applications where id=p_application_id for update;
 if not found or v_app.status<>'pending' then raise exception 'Application is no longer pending'; end if;
 perform 1 from public.profiles where id=v_app.provider_id and role='provider' and service_category=v_job.service_category
 and (service_category not in ('Doctor','Nurse') or is_verified) for share;
 if not found then raise exception 'Provider is no longer eligible'; end if;
 update public.applications set status=case when id=p_application_id then 'accepted' else 'rejected' end where job_id=v_job.id and status='pending';
 update public.jobs set status='assigned',updated_at=now() where id=v_job.id;
 insert into public.engagements(source_type,job_id,customer_id,provider_id,pricing_type,agreed_amount_tzs,status)
 values('job',v_job.id,v_job.customer_id,v_app.provider_id,v_job.pricing_type,coalesce(v_app.proposed_rate_tzs,v_job.amount_tzs),'accepted') returning id into v_eng;
 insert into public.conversations(engagement_id,customer_id,provider_id) values(v_eng,v_job.customer_id,v_app.provider_id) returning id into v_conv;
 insert into public.messages(conversation_id,sender_id,body) values(v_conv,auth.uid(),'Application accepted. Coordinate the job here.');
 return query select v_eng,v_conv;
end $$;

create or replace function public.provider_accept_engagement(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 perform 1 from public.profiles where id=auth.uid() and role='provider' and (service_category not in ('Doctor','Nurse') or is_verified) for share;
 if not found then raise exception 'Provider verification is required'; end if;
 update public.engagements set status='accepted',updated_at=now() where id=p_engagement_id and provider_id=auth.uid() and status='requested';
 if not found then raise exception 'Inquiry not found or already handled'; end if;
end $$;

create or replace function public.cancel_engagement(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_job uuid;
begin
 -- Job first, matching the order of the hire RPC.
 select job_id into v_job from public.engagements where id=p_engagement_id and (customer_id=auth.uid() or provider_id=auth.uid());
 if v_job is not null then perform 1 from public.jobs where id=v_job for update; end if;
 update public.engagements set status='cancelled',updated_at=now() where id=p_engagement_id and status in ('requested','accepted') and (customer_id=auth.uid() or provider_id=auth.uid());
 if not found then raise exception 'Only a match that has not started can be cancelled'; end if;
 update public.jobs set status='cancelled',updated_at=now() where id=v_job;
end $$;

create or replace function public.cancel_job(p_job_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 update public.jobs set status='cancelled',updated_at=now() where id=p_job_id and customer_id=auth.uid() and status='open';
 if not found then raise exception 'Only your open jobs can be cancelled'; end if;
 update public.applications set status='rejected' where job_id=p_job_id and status='pending';
end $$;

create or replace function public.propose_billable_time(p_engagement_id uuid,p_minutes integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 if p_minutes is null or p_minutes not between 1 and 43200 then raise exception 'Enter 1 to 43200 whole minutes'; end if;
 update public.engagements set billable_minutes=p_minutes,time_approved=false,updated_at=now()
 where id=p_engagement_id and provider_id=auth.uid() and pricing_type='hourly' and status='completed' and not payment_sent;
 if not found then raise exception 'Time can only be proposed after completion and before payment'; end if;
end $$;
create or replace function public.approve_billable_time(p_engagement_id uuid,p_minutes integer)
returns void language plpgsql security definer set search_path=public as $$
begin
 update public.engagements set time_approved=true,updated_at=now() where id=p_engagement_id and customer_id=auth.uid()
 and pricing_type='hourly' and status='completed' and billable_minutes=p_minutes and not payment_sent;
 if not found then raise exception 'No proposed time is ready to approve'; end if;
end $$;
drop function if exists public.mark_payment_sent(uuid);
create or replace function public.mark_payment_sent(p_engagement_id uuid,p_expected_amount numeric)
returns void language plpgsql security definer set search_path=public as $$
begin
 update public.engagements set payment_sent=true,payment_status='pending',updated_at=now()
 where id=p_engagement_id and customer_id=auth.uid() and status='completed'
 and total_amount_tzs=p_expected_amount
 and (pricing_type='fixed' or (billable_minutes is not null and time_approved));
 if not found then raise exception 'Complete the job and agree the billable time before confirming payment'; end if;
end $$;

create or replace function public.upsert_engagement_location(p_engagement_id uuid,p_lat double precision,p_lng double precision)
returns void language plpgsql security definer set search_path=public as $$
begin
 if not public.valid_coordinates(p_lat,p_lng) then raise exception 'Invalid coordinates'; end if;
 perform 1 from public.engagements where id=p_engagement_id and status in ('accepted','in_progress')
 and (customer_id=auth.uid() or provider_id=auth.uid()) for share;
 if not found then raise exception 'Live location requires an active match'; end if;
 insert into public.engagement_locations(engagement_id,user_id,lat,lng,updated_at) values(p_engagement_id,auth.uid(),p_lat,p_lng,now())
 on conflict(engagement_id,user_id) do update set lat=excluded.lat,lng=excluded.lng,updated_at=now();
end $$;
create or replace function public.stop_sharing_location(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
 delete from public.engagement_locations where engagement_id=p_engagement_id and user_id=auth.uid();
end $$;
create or replace function public.clear_closed_match_locations()
returns trigger language plpgsql security definer set search_path=public as $$
begin
 if new.status not in ('accepted','in_progress') then delete from public.engagement_locations where engagement_id=new.id; end if;
 return new;
end $$;
drop trigger if exists clear_closed_match_locations on public.engagements;
create trigger clear_closed_match_locations after update of status on public.engagements for each row execute function public.clear_closed_match_locations();
delete from public.engagement_locations l using public.engagements e where l.engagement_id=e.id and e.status not in ('accepted','in_progress');

create or replace function public.submit_review(p_engagement_id uuid,p_rating integer,p_comment text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_provider uuid;v_id uuid;
begin
 if p_rating is null or p_rating not between 1 and 5 then raise exception 'Rating must be 1 to 5'; end if;
 select provider_id into v_provider from public.engagements where id=p_engagement_id and customer_id=auth.uid() and status='paid';
 if v_provider is null then raise exception 'Only the customer can review a paid engagement'; end if;
 -- Serialize aggregate changes for concurrent reviews of the same provider.
 perform 1 from public.profiles where id=v_provider for update;
 insert into public.reviews(engagement_id,customer_id,provider_id,rating,comment)
 values(p_engagement_id,auth.uid(),v_provider,p_rating,nullif(trim(p_comment),'')) returning id into v_id;
 update public.profiles set rating_avg=(select round(avg(rating),2) from public.reviews where provider_id=v_provider),
 review_count=(select count(*) from public.reviews where provider_id=v_provider),updated_at=now() where id=v_provider;
 return v_id;
exception when unique_violation then raise exception 'A review has already been submitted for this match';
end $$;


create or replace function public.begin_engagement(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_job uuid;
begin
 select job_id into v_job from public.engagements where id=p_engagement_id and (customer_id=auth.uid() or provider_id=auth.uid());
 if v_job is not null then perform 1 from public.jobs where id=v_job for update; end if;
 if not exists(select 1 from public.engagements e join public.profiles p on p.id=e.provider_id where e.id=p_engagement_id
 and (p.service_category not in ('Doctor','Nurse') or p.is_verified)) then raise exception 'Provider verification is required'; end if;
 update public.engagements set status='in_progress',updated_at=now() where id=p_engagement_id and status='accepted' and (customer_id=auth.uid() or provider_id=auth.uid());
 if not found then raise exception 'This match cannot be started'; end if;
 update public.jobs set status='in_progress',updated_at=now() where id=v_job;
end $$;
create or replace function public.confirm_completion(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
declare v_job uuid;
begin
 select job_id into v_job from public.engagements where id=p_engagement_id and (customer_id=auth.uid() or provider_id=auth.uid());
 if v_job is not null then perform 1 from public.jobs where id=v_job for update; end if;
 update public.engagements set customer_completed=customer_completed or customer_id=auth.uid(),
 provider_completed=provider_completed or provider_id=auth.uid(),updated_at=now()
 where id=p_engagement_id and status='in_progress' and (customer_id=auth.uid() or provider_id=auth.uid());
 if not found then raise exception 'Active match not found'; end if;
 update public.engagements set status='completed',payment_status='pending',updated_at=now()
 where id=p_engagement_id and customer_completed and provider_completed;
 update public.jobs set status='completed',updated_at=now() where id=v_job and exists(select 1 from public.engagements where id=p_engagement_id and status='completed');
end $$;

-- Restrict only KaziChap functions; leave unrelated project functions untouched.
do $$ declare f record; begin
 for f in select p.oid::regprocedure as signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname='public' and p.proname=any(array['handle_new_user','get_my_profile','set_my_location','set_online','get_nearby_providers',
 'get_nearby_jobs','create_job','start_direct_inquiry','accept_application','provider_accept_engagement','begin_engagement','confirm_completion',
 'mark_payment_sent','mark_payment_received','upsert_engagement_location','submit_review','apply_to_job','cancel_engagement','cancel_job',
 'propose_billable_time','approve_billable_time','stop_sharing_location','clear_closed_match_locations','valid_coordinates','valid_category'])
 loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  if f.proname not in ('handle_new_user','clear_closed_match_locations') then execute format('grant execute on function %s to authenticated',f.signature); end if;
 end loop;
end $$;

-- Broad dashboard discovery is refreshed by polling; Realtime is scoped to participants.
do $$ begin alter publication supabase_realtime add table public.engagements; exception when duplicate_object then null; end $$;
do $$ begin alter publication supabase_realtime add table public.applications; exception when duplicate_object then null; end $$;
commit;
