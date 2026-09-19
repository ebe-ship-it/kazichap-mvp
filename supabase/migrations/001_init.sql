-- KaziChap MVP database
-- Run in Supabase SQL Editor on a fresh project.

create schema if not exists extensions;
create extension if not exists postgis with schema extensions;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null,
  role text not null check (role in ('customer','provider')),
  service_category text,
  hourly_rate_tzs numeric(12,2),
  bio text,
  is_online boolean not null default false,
  is_verified boolean not null default false,
  verification_status text not null default 'unverified' check (verification_status in ('unverified','pending','verified','rejected')),
  lat double precision,
  lng double precision,
  location extensions.geography(point,4326),
  area text,
  rating_avg numeric(3,2) not null default 0,
  review_count integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (role = 'customer' or service_category is not null),
  check (role = 'customer' or hourly_rate_tzs is not null)
);
create index if not exists profiles_geo_idx on public.profiles using gist(location);
create index if not exists profiles_provider_search_idx on public.profiles(role, service_category, is_online);

create table if not exists public.private_contacts (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  phone text not null,
  created_at timestamptz not null default now()
);

create table if not exists public.jobs (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  description text not null,
  service_category text not null,
  pricing_type text not null check (pricing_type in ('hourly','fixed')),
  amount_tzs numeric(12,2) not null check (amount_tzs > 0),
  status text not null default 'open' check (status in ('open','assigned','in_progress','completed','cancelled')),
  lat double precision not null,
  lng double precision not null,
  location extensions.geography(point,4326) not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists jobs_geo_idx on public.jobs using gist(location);
create index if not exists jobs_open_category_idx on public.jobs(status, service_category);

create table if not exists public.applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references public.jobs(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  note text,
  proposed_rate_tzs numeric(12,2) check (proposed_rate_tzs is null or proposed_rate_tzs > 0),
  status text not null default 'pending' check (status in ('pending','accepted','rejected','withdrawn')),
  created_at timestamptz not null default now(),
  unique(job_id, provider_id)
);

create table if not exists public.engagements (
  id uuid primary key default gen_random_uuid(),
  source_type text not null check (source_type in ('job','direct')),
  job_id uuid references public.jobs(id) on delete set null,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  pricing_type text not null check (pricing_type in ('hourly','fixed')),
  agreed_amount_tzs numeric(12,2) not null check (agreed_amount_tzs > 0),
  status text not null default 'requested' check (status in ('requested','accepted','in_progress','completed','paid','cancelled')),
  customer_completed boolean not null default false,
  provider_completed boolean not null default false,
  payment_sent boolean not null default false,
  payment_received boolean not null default false,
  payment_status text not null default 'unpaid' check (payment_status in ('unpaid','pending','paid')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists engagements_customer_idx on public.engagements(customer_id, created_at desc);
create index if not exists engagements_provider_idx on public.engagements(provider_id, created_at desc);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null unique references public.engagements(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id) on delete cascade,
  body text not null check (char_length(body) between 1 and 2000),
  created_at timestamptz not null default now()
);
create index if not exists messages_conversation_idx on public.messages(conversation_id, created_at);

create table if not exists public.engagement_locations (
  engagement_id uuid not null references public.engagements(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  lat double precision not null,
  lng double precision not null,
  updated_at timestamptz not null default now(),
  primary key (engagement_id, user_id)
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  engagement_id uuid not null unique references public.engagements(id) on delete cascade,
  customer_id uuid not null references public.profiles(id) on delete cascade,
  provider_id uuid not null references public.profiles(id) on delete cascade,
  rating integer not null check (rating between 1 and 5),
  comment text,
  created_at timestamptz not null default now()
);

-- Auth -> profile trigger
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles(id, full_name, role, service_category, hourly_rate_tzs, bio)
  values(
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name','KaziChap user'),
    coalesce(new.raw_user_meta_data->>'role','customer'),
    nullif(new.raw_user_meta_data->>'service_category',''),
    nullif(new.raw_user_meta_data->>'hourly_rate_tzs','')::numeric,
    nullif(new.raw_user_meta_data->>'bio','')
  );
  if nullif(new.raw_user_meta_data->>'phone','') is not null then
    insert into public.private_contacts(user_id, phone) values(new.id, new.raw_user_meta_data->>'phone');
  end if;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();

-- RLS
alter table public.profiles enable row level security;
alter table public.private_contacts enable row level security;
alter table public.jobs enable row level security;
alter table public.applications enable row level security;
alter table public.engagements enable row level security;
alter table public.conversations enable row level security;
alter table public.messages enable row level security;
alter table public.engagement_locations enable row level security;
alter table public.reviews enable row level security;

create policy "profiles readable by authenticated users" on public.profiles for select to authenticated using (true);
create policy "private contact owner only" on public.private_contacts for all to authenticated using (auth.uid()=user_id) with check (auth.uid()=user_id);

create policy "open jobs or own jobs readable" on public.jobs for select to authenticated using (status='open' or customer_id=auth.uid());
create policy "customers insert own jobs" on public.jobs for insert to authenticated with check (customer_id=auth.uid());

create policy "application participants read" on public.applications for select to authenticated using (
  provider_id=auth.uid() or exists(select 1 from public.jobs j where j.id=job_id and j.customer_id=auth.uid())
);
create policy "providers apply as self" on public.applications for insert to authenticated with check (
  provider_id=auth.uid()
  and exists(
    select 1 from public.profiles p join public.jobs j on j.id=job_id
    where p.id=auth.uid() and p.role='provider' and j.status='open' and p.service_category=j.service_category
      and (p.service_category not in ('Doctor','Nurse') or p.is_verified=true)
  )
);

create policy "engagement participants read" on public.engagements for select to authenticated using (customer_id=auth.uid() or provider_id=auth.uid());
create policy "conversation participants read" on public.conversations for select to authenticated using (customer_id=auth.uid() or provider_id=auth.uid());
create policy "message participants read" on public.messages for select to authenticated using (exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=auth.uid() or c.provider_id=auth.uid())));
create policy "message participants send" on public.messages for insert to authenticated with check (sender_id=auth.uid() and exists(select 1 from public.conversations c where c.id=conversation_id and (c.customer_id=auth.uid() or c.provider_id=auth.uid())));
create policy "match participants read locations" on public.engagement_locations for select to authenticated using (exists(select 1 from public.engagements e where e.id=engagement_id and (e.customer_id=auth.uid() or e.provider_id=auth.uid())));
create policy "reviews readable" on public.reviews for select to authenticated using (true);

-- Limit direct table reads so stored exact discovery locations are not exposed.
revoke select on table public.profiles from authenticated;
grant select (id,full_name,role,service_category,hourly_rate_tzs,bio,is_online,is_verified,verification_status,rating_avg,review_count,created_at,updated_at) on table public.profiles to authenticated;
revoke select on table public.jobs from authenticated;
grant select (id,customer_id,title,description,service_category,pricing_type,amount_tzs,status,created_at,updated_at) on table public.jobs to authenticated;

-- Helpers
create or replace function public.get_my_profile()
returns table(id uuid,full_name text,role text,service_category text,hourly_rate_tzs numeric,bio text,is_online boolean,is_verified boolean,lat double precision,lng double precision,area text,rating_avg numeric,review_count integer)
language sql stable security definer set search_path=public as $$
  select p.id,p.full_name,p.role,p.service_category,p.hourly_rate_tzs,p.bio,p.is_online,p.is_verified,p.lat,p.lng,p.area,p.rating_avg,p.review_count
  from public.profiles p where p.id=auth.uid();
$$;

create or replace function public.set_my_location(p_lat double precision, p_lng double precision, p_area text default null)
returns void language plpgsql security definer set search_path=public,extensions as $$
begin
  update public.profiles set lat=p_lat,lng=p_lng,location=extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography,area=p_area,updated_at=now() where id=auth.uid();
  if not found then raise exception 'Profile not found'; end if;
end; $$;

create or replace function public.set_online(p_online boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.profiles set is_online=p_online,updated_at=now() where id=auth.uid() and role='provider';
  if not found then raise exception 'Only providers can change online status'; end if;
end; $$;

create or replace function public.get_nearby_providers(p_lat double precision,p_lng double precision,p_category text,p_radius_meters double precision default 15000)
returns table(id uuid,full_name text,service_category text,hourly_rate_tzs numeric,dist_meters double precision,is_verified boolean,rating_avg numeric,review_count integer,bio text)
language sql stable security definer set search_path=public,extensions as $$
  select p.id,p.full_name,p.service_category,p.hourly_rate_tzs,
    extensions.st_distance(p.location,extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography)::double precision,
    p.is_verified,p.rating_avg,p.review_count,p.bio
  from public.profiles p
  where p.role='provider' and p.is_online=true and p.location is not null and p.service_category=p_category
    and (p.service_category not in ('Doctor','Nurse') or p.is_verified=true)
    and extensions.st_dwithin(p.location,extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography,p_radius_meters)
  order by p.location operator(extensions.<->) extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography
  limit 50;
$$;

create or replace function public.get_nearby_jobs(p_lat double precision,p_lng double precision,p_category text,p_radius_meters double precision default 20000)
returns table(id uuid,customer_id uuid,title text,description text,service_category text,pricing_type text,amount_tzs numeric,dist_meters double precision,created_at timestamptz)
language sql stable security definer set search_path=public,extensions as $$
  select j.id,j.customer_id,j.title,j.description,j.service_category,j.pricing_type,j.amount_tzs,
    extensions.st_distance(j.location,extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography)::double precision,j.created_at
  from public.jobs j
  where j.status='open' and j.service_category=p_category
    and extensions.st_dwithin(j.location,extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography,p_radius_meters)
  order by j.location operator(extensions.<->) extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography
  limit 50;
$$;

create or replace function public.create_job(p_title text,p_description text,p_category text,p_pricing_type text,p_amount_tzs numeric,p_lat double precision,p_lng double precision)
returns uuid language plpgsql security definer set search_path=public,extensions as $$
declare v_id uuid;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='customer') then raise exception 'Only customers can post jobs'; end if;
  insert into public.jobs(customer_id,title,description,service_category,pricing_type,amount_tzs,lat,lng,location)
  values(auth.uid(),p_title,p_description,p_category,p_pricing_type,p_amount_tzs,p_lat,p_lng,extensions.st_setsrid(extensions.st_point(p_lng,p_lat),4326)::extensions.geography)
  returning id into v_id;
  return v_id;
end; $$;

create or replace function public.start_direct_inquiry(p_provider_id uuid,p_message text default null)
returns table(engagement_id uuid,conversation_id uuid)
language plpgsql security definer set search_path=public as $$
declare v_eng uuid; v_conv uuid; v_rate numeric;
begin
  if not exists(select 1 from public.profiles where id=auth.uid() and role='customer') then raise exception 'Only customers can start an inquiry'; end if;
  select hourly_rate_tzs into v_rate from public.profiles where id=p_provider_id and role='provider';
  if v_rate is null then raise exception 'Provider not found'; end if;
  insert into public.engagements(source_type,customer_id,provider_id,pricing_type,agreed_amount_tzs,status)
  values('direct',auth.uid(),p_provider_id,'hourly',v_rate,'requested') returning id into v_eng;
  insert into public.conversations(engagement_id,customer_id,provider_id) values(v_eng,auth.uid(),p_provider_id) returning id into v_conv;
  if nullif(trim(p_message),'') is not null then insert into public.messages(conversation_id,sender_id,body) values(v_conv,auth.uid(),p_message); end if;
  return query select v_eng,v_conv;
end; $$;

create or replace function public.accept_application(p_application_id uuid)
returns table(engagement_id uuid,conversation_id uuid)
language plpgsql security definer set search_path=public as $$
declare v_app public.applications%rowtype; v_job public.jobs%rowtype; v_eng uuid; v_conv uuid; v_amount numeric;
begin
  select * into v_app from public.applications where id=p_application_id for update;
  if not found then raise exception 'Application not found'; end if;
  select * into v_job from public.jobs where id=v_app.job_id for update;
  if v_job.customer_id<>auth.uid() then raise exception 'Not allowed'; end if;
  if v_job.status<>'open' then raise exception 'Job is no longer open'; end if;
  v_amount:=coalesce(v_app.proposed_rate_tzs,v_job.amount_tzs);
  update public.applications set status=case when id=p_application_id then 'accepted' else 'rejected' end where job_id=v_job.id and status='pending';
  update public.jobs set status='assigned',updated_at=now() where id=v_job.id;
  insert into public.engagements(source_type,job_id,customer_id,provider_id,pricing_type,agreed_amount_tzs,status)
  values('job',v_job.id,v_job.customer_id,v_app.provider_id,v_job.pricing_type,v_amount,'accepted') returning id into v_eng;
  insert into public.conversations(engagement_id,customer_id,provider_id) values(v_eng,v_job.customer_id,v_app.provider_id) returning id into v_conv;
  insert into public.messages(conversation_id,sender_id,body) values(v_conv,auth.uid(),'Application accepted. You can coordinate the job here.');
  return query select v_eng,v_conv;
end; $$;

create or replace function public.provider_accept_engagement(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.engagements set status='accepted',updated_at=now() where id=p_engagement_id and provider_id=auth.uid() and status='requested';
  if not found then raise exception 'Inquiry not found or already handled'; end if;
end; $$;

create or replace function public.begin_engagement(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.engagements set status='in_progress',updated_at=now() where id=p_engagement_id and status='accepted' and (customer_id=auth.uid() or provider_id=auth.uid());
  if not found then raise exception 'Match cannot be started'; end if;
  update public.jobs set status='in_progress',updated_at=now() where id=(select job_id from public.engagements where id=p_engagement_id) and status='assigned';
end; $$;

create or replace function public.confirm_completion(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.engagements set
    customer_completed = customer_completed or customer_id=auth.uid(),
    provider_completed = provider_completed or provider_id=auth.uid(),
    updated_at=now()
  where id=p_engagement_id and status='in_progress' and (customer_id=auth.uid() or provider_id=auth.uid());
  if not found then raise exception 'Active match not found'; end if;
  update public.engagements set status='completed',payment_status='pending',updated_at=now() where id=p_engagement_id and customer_completed and provider_completed;
  update public.jobs set status='completed',updated_at=now() where id=(select job_id from public.engagements where id=p_engagement_id and status='completed');
end; $$;

create or replace function public.mark_payment_sent(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.engagements set payment_sent=true,payment_status='pending',updated_at=now() where id=p_engagement_id and customer_id=auth.uid() and status='completed';
  if not found then raise exception 'Payment cannot be marked sent'; end if;
end; $$;

create or replace function public.mark_payment_received(p_engagement_id uuid)
returns void language plpgsql security definer set search_path=public as $$
begin
  update public.engagements set payment_received=true,updated_at=now() where id=p_engagement_id and provider_id=auth.uid() and status='completed' and payment_sent=true;
  if not found then raise exception 'Waiting for customer payment confirmation'; end if;
  update public.engagements set payment_status='paid',status='paid',updated_at=now() where id=p_engagement_id and payment_sent and payment_received;
end; $$;

create or replace function public.upsert_engagement_location(p_engagement_id uuid,p_lat double precision,p_lng double precision)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not exists(select 1 from public.engagements where id=p_engagement_id and status in ('accepted','in_progress') and (customer_id=auth.uid() or provider_id=auth.uid())) then raise exception 'Live location is only available for an active match'; end if;
  insert into public.engagement_locations(engagement_id,user_id,lat,lng,updated_at) values(p_engagement_id,auth.uid(),p_lat,p_lng,now())
  on conflict(engagement_id,user_id) do update set lat=excluded.lat,lng=excluded.lng,updated_at=now();
end; $$;

create or replace function public.submit_review(p_engagement_id uuid,p_rating integer,p_comment text default null)
returns uuid language plpgsql security definer set search_path=public as $$
declare v_provider uuid; v_id uuid;
begin
  if p_rating<1 or p_rating>5 then raise exception 'Rating must be 1 to 5'; end if;
  select provider_id into v_provider from public.engagements where id=p_engagement_id and customer_id=auth.uid() and status='paid';
  if v_provider is null then raise exception 'Only the customer can review a paid engagement'; end if;
  insert into public.reviews(engagement_id,customer_id,provider_id,rating,comment) values(p_engagement_id,auth.uid(),v_provider,p_rating,p_comment) returning id into v_id;
  update public.profiles p set rating_avg=(select round(avg(r.rating)::numeric,2) from public.reviews r where r.provider_id=v_provider),review_count=(select count(*) from public.reviews r where r.provider_id=v_provider),updated_at=now() where p.id=v_provider;
  return v_id;
end; $$;

revoke all on function public.get_my_profile() from public;
revoke all on function public.set_my_location(double precision,double precision,text) from public;
revoke all on function public.set_online(boolean) from public;
revoke all on function public.get_nearby_providers(double precision,double precision,text,double precision) from public;
revoke all on function public.get_nearby_jobs(double precision,double precision,text,double precision) from public;
revoke all on function public.create_job(text,text,text,text,numeric,double precision,double precision) from public;
revoke all on function public.start_direct_inquiry(uuid,text) from public;
revoke all on function public.accept_application(uuid) from public;
revoke all on function public.provider_accept_engagement(uuid) from public;
revoke all on function public.begin_engagement(uuid) from public;
revoke all on function public.confirm_completion(uuid) from public;
revoke all on function public.mark_payment_sent(uuid) from public;
revoke all on function public.mark_payment_received(uuid) from public;
revoke all on function public.upsert_engagement_location(uuid,double precision,double precision) from public;
revoke all on function public.submit_review(uuid,integer,text) from public;

grant execute on function public.get_my_profile() to authenticated;
grant execute on function public.set_my_location(double precision,double precision,text) to authenticated;
grant execute on function public.set_online(boolean) to authenticated;
grant execute on function public.get_nearby_providers(double precision,double precision,text,double precision) to authenticated;
grant execute on function public.get_nearby_jobs(double precision,double precision,text,double precision) to authenticated;
grant execute on function public.create_job(text,text,text,text,numeric,double precision,double precision) to authenticated;
grant execute on function public.start_direct_inquiry(uuid,text) to authenticated;
grant execute on function public.accept_application(uuid) to authenticated;
grant execute on function public.provider_accept_engagement(uuid) to authenticated;
grant execute on function public.begin_engagement(uuid) to authenticated;
grant execute on function public.confirm_completion(uuid) to authenticated;
grant execute on function public.mark_payment_sent(uuid) to authenticated;
grant execute on function public.mark_payment_received(uuid) to authenticated;
grant execute on function public.upsert_engagement_location(uuid,double precision,double precision) to authenticated;
grant execute on function public.submit_review(uuid,integer,text) to authenticated;

-- Realtime for MVP chat + map. Supabase recommends Broadcast for higher-scale/high-frequency use.
do $$ begin
  alter publication supabase_realtime add table public.messages;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table public.engagement_locations;
exception when duplicate_object then null; end $$;
