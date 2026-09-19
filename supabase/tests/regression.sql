-- RUN ONLY IN A TEST PROJECT, after bootstrap.sql / migration 002.
-- No email is sent: test auth records are inserted directly in this transaction.
-- All test users and marketplace records are rolled back at the end.
-- A failing assertion aborts the transaction. Run ROLLBACK if your editor leaves it open.
begin;
select set_config('kzc.customer',gen_random_uuid()::text,true);
select set_config('kzc.provider',gen_random_uuid()::text,true);
select set_config('kzc.stranger',gen_random_uuid()::text,true);
select set_config('kzc.doctor',gen_random_uuid()::text,true);
insert into auth.users(id,email,raw_user_meta_data) values
 (current_setting('kzc.customer')::uuid,'kzc-c-'||current_setting('kzc.customer')||'@example.invalid','{"full_name":"Test Customer","role":"customer"}'::jsonb),
 (current_setting('kzc.provider')::uuid,'kzc-p-'||current_setting('kzc.provider')||'@example.invalid','{"full_name":"Test Provider","role":"provider","service_category":"Plumber","hourly_rate_tzs":15000}'::jsonb),
 (current_setting('kzc.stranger')::uuid,'kzc-s-'||current_setting('kzc.stranger')||'@example.invalid','{"full_name":"Test Stranger","role":"customer"}'::jsonb),
 (current_setting('kzc.doctor')::uuid,'kzc-d-'||current_setting('kzc.doctor')||'@example.invalid','{"full_name":"Test Doctor","role":"provider","service_category":"Doctor","hourly_rate_tzs":30000}'::jsonb);

set local role authenticated;
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.set_my_location(-6.7924,39.2083,'Test location');
select public.set_online(true);
-- Direct profile mutation and self-verification must be denied.
do $$ begin
 begin
  update public.profiles set is_verified=true where id=auth.uid();
  raise exception 'FAIL: provider could self-verify';
 exception when insufficient_privilege then null;
 end;
 begin
  perform lat from public.profiles;
  raise exception 'FAIL: raw profile coordinates exposed';
 exception when insufficient_privilege then null;
 end;
end $$;

select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select public.set_my_location(-6.7924,39.2083,'Test location');
select set_config('kzc.job',public.create_job('Test plumbing task','A regression test job description','Plumber','fixed',20000,-6.7924,39.2083)::text,true);
-- Customers cannot forge an accepted application or insert arbitrary jobs directly.
do $$ begin
 begin
  insert into public.applications(job_id,provider_id,status) values(current_setting('kzc.job')::uuid,auth.uid(),'accepted');
  raise exception 'FAIL: direct application insert allowed';
 exception when insufficient_privilege then null;
 end;
end $$;

select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select set_config('kzc.application',public.apply_to_job(current_setting('kzc.job')::uuid,'I can do this work',22000)::text,true);
do $$ declare rejected boolean:=false;begin
 begin perform public.apply_to_job(current_setting('kzc.job')::uuid,'Duplicate',22000);
 exception when others then rejected:=position('already applied' in sqlerrm)>0;end;
 if not rejected then raise exception 'FAIL: duplicate application not rejected correctly';end if;
end $$;

select set_config('request.jwt.claim.sub',current_setting('kzc.stranger'),true);
do $$ declare rejected boolean:=false;begin
 begin perform public.accept_application(current_setting('kzc.application')::uuid);
 exception when others then rejected:=position('not yours' in sqlerrm)>0;end;
 if not rejected then raise exception 'FAIL: unrelated customer can accept application';end if;
end $$;

select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select set_config('kzc.engagement',engagement_id::text,true),set_config('kzc.conversation',conversation_id::text,true)
 from public.accept_application(current_setting('kzc.application')::uuid);
do $$ begin
 if not exists(select 1 from public.engagements where id=current_setting('kzc.engagement')::uuid and status='accepted' and agreed_amount_tzs=22000) then
  raise exception 'FAIL: accepted match or proposed fixed rate incorrect';end if;
end $$;
select public.upsert_engagement_location(current_setting('kzc.engagement')::uuid,-6.7924,39.2083);
insert into public.messages(conversation_id,sender_id,body) values(current_setting('kzc.conversation')::uuid,auth.uid(),'Test conversation message');

select set_config('request.jwt.claim.sub',current_setting('kzc.stranger'),true);
do $$ begin
 if exists(select 1 from public.engagement_locations where engagement_id=current_setting('kzc.engagement')::uuid) then raise exception 'FAIL: location leaked to unrelated account';end if;
 if exists(select 1 from public.messages where conversation_id=current_setting('kzc.conversation')::uuid) then raise exception 'FAIL: message leaked to unrelated account';end if;
end $$;

select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select public.begin_engagement(current_setting('kzc.engagement')::uuid);
select public.confirm_completion(current_setting('kzc.engagement')::uuid);
do $$ begin
 if not exists(select 1 from public.engagements where id=current_setting('kzc.engagement')::uuid and status='in_progress') then raise exception 'FAIL: one completion closed the match';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.confirm_completion(current_setting('kzc.engagement')::uuid);
select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select public.mark_payment_sent(current_setting('kzc.engagement')::uuid,22000);
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.mark_payment_received(current_setting('kzc.engagement')::uuid);
select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select public.submit_review(current_setting('kzc.engagement')::uuid,5,'Test review');

-- Test hourly billing, changed time proposals and stale amount rejection.
select set_config('kzc.hourly',engagement_id::text,true) from public.start_direct_inquiry(current_setting('kzc.provider')::uuid,'Test hourly inquiry');
do $$ declare first_id uuid;second_id uuid;begin
 first_id:=current_setting('kzc.hourly')::uuid;
 select engagement_id into second_id from public.start_direct_inquiry(current_setting('kzc.provider')::uuid,'Repeated click');
 if first_id<>second_id then raise exception 'FAIL: repeated inquiry created a duplicate';end if;
end $$;
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.provider_accept_engagement(current_setting('kzc.hourly')::uuid);
select public.begin_engagement(current_setting('kzc.hourly')::uuid);
select public.confirm_completion(current_setting('kzc.hourly')::uuid);
select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
select public.confirm_completion(current_setting('kzc.hourly')::uuid);
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.propose_billable_time(current_setting('kzc.hourly')::uuid,90);
select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
do $$ begin
 if not exists(select 1 from public.engagements where id=current_setting('kzc.hourly')::uuid and total_amount_tzs=22500) then raise exception 'FAIL: hourly total calculation';end if;
end $$;
select public.approve_billable_time(current_setting('kzc.hourly')::uuid,90);
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.propose_billable_time(current_setting('kzc.hourly')::uuid,120);
select set_config('request.jwt.claim.sub',current_setting('kzc.customer'),true);
do $$ declare rejected boolean:=false;begin
 if exists(select 1 from public.engagements where id=current_setting('kzc.hourly')::uuid and time_approved) then raise exception 'FAIL: revised time retained approval';end if;
 begin perform public.approve_billable_time(current_setting('kzc.hourly')::uuid,90);
 exception when others then rejected:=position('ready to approve' in sqlerrm)>0;end;
 if not rejected then raise exception 'FAIL: stale time approval accepted';end if;
end $$;
select public.approve_billable_time(current_setting('kzc.hourly')::uuid,120);
do $$ declare rejected boolean:=false;begin
 begin perform public.mark_payment_sent(current_setting('kzc.hourly')::uuid,22500);
 exception when others then rejected:=position('before confirming payment' in sqlerrm)>0;end;
 if not rejected then raise exception 'FAIL: stale payment amount accepted';end if;
end $$;
select public.mark_payment_sent(current_setting('kzc.hourly')::uuid,30000);
select set_config('request.jwt.claim.sub',current_setting('kzc.provider'),true);
select public.mark_payment_received(current_setting('kzc.hourly')::uuid);

-- An unverified doctor cannot go online, even by calling the RPC directly.
select set_config('request.jwt.claim.sub',current_setting('kzc.doctor'),true);
select public.set_my_location(-6.7924,39.2083,'Test location');
do $$ declare rejected boolean:=false;begin
 begin perform public.set_online(true);
 exception when others then rejected:=position('verification' in sqlerrm)>0;end;
 if not rejected then raise exception 'FAIL: unverified doctor went online';end if;
end $$;

-- Anonymous callers cannot execute the security-definer hiring RPC.
reset role;
set local role anon;
do $$ begin
 begin perform public.accept_application(current_setting('kzc.application')::uuid);
  raise exception 'FAIL: anonymous hiring RPC allowed';
 exception when insufficient_privilege then null;end;
end $$;
reset role;
-- Check removal as owner, so a restrictive RLS policy cannot hide retained rows.
do $$ begin
 if exists(select 1 from public.engagement_locations where engagement_id=current_setting('kzc.engagement')::uuid) then raise exception 'FAIL: closed-match coordinates were retained';end if;
 raise notice 'All KaziChap database regression assertions passed. Rolling back test data.';
end $$;
rollback;
