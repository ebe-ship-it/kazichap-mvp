"use client";
import { type FormEvent, useCallback, useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import { MapPin, MessageCircle, Plus, ShieldCheck, Star, UserRoundSearch } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { km, money, SERVICE_CATEGORIES } from "@/lib/constants";
import { errorMessage } from "@/lib/validation";
import { useRefresh } from "@/lib/use-refresh";
import { type Profile } from "./dashboard-shell";
import { StatusPill } from "./status-pill";
import { ActionDialog } from "./action-dialog";

type Provider={id:string;full_name:string;service_category:string;hourly_rate_tzs:number;dist_meters:number;is_verified:boolean;rating_avg:number;review_count:number;bio:string|null};
type Job={id:string;title:string;service_category:string;pricing_type:string;amount_tzs:number;status:string};
type Application={id:string;job_id:string;status:string;note:string|null;proposed_rate_tzs:number|null;profiles:{full_name:string;service_category:string|null}|null};
type Engagement={id:string;status:string;pricing_type:string;agreed_amount_tzs:number;profiles:{full_name:string;service_category:string|null}|null};
export function CustomerDashboard({profile}:{profile:Profile}) {
 const supabase=createClient();const router=useRouter();
 const [providers,setProviders]=useState<Provider[]>([]);const [category,setCategory]=useState("Plumber");
 const [jobs,setJobs]=useState<Job[]>([]);const [apps,setApps]=useState<Application[]>([]);const [engagements,setEngagements]=useState<Engagement[]>([]);
 const [error,setError]=useState("");const [notice,setNotice]=useState("");const [busy,setBusy]=useState(false);const [loading,setLoading]=useState(true);
 const [selected,setSelected]=useState<Provider|null>(null);const [cancelJob,setCancelJob]=useState<Job|null>(null);const [dialogError,setDialogError]=useState("");
 const refresh=useCallback(async()=>{
  const [p,j,e]=await Promise.all([
   supabase.rpc("get_nearby_providers",{p_lat:profile.lat,p_lng:profile.lng,p_category:category,p_radius_meters:15000}),
   supabase.from("jobs").select("id,title,service_category,pricing_type,amount_tzs,status").eq("customer_id",profile.id).order("created_at",{ascending:false}).limit(100),
   supabase.from("engagements").select("id,status,pricing_type,agreed_amount_tzs,profiles!engagements_provider_id_fkey(full_name,service_category)").eq("customer_id",profile.id).order("created_at",{ascending:false}).limit(100)
  ]);
  const failure=p.error||j.error||e.error;if(failure)throw failure;
  setProviders((p.data||[]) as Provider[]);setJobs((j.data||[]) as Job[]);setEngagements((e.data||[]) as unknown as Engagement[]);setLoading(false);
 },[supabase,profile.id,profile.lat,profile.lng,category]);
 useRefresh(refresh,setError);
 useEffect(()=>{let active=true;void (async()=>{
  if(!jobs.length){setApps([]);return;}
  const {data,error}=await supabase.from("applications").select("id,job_id,status,note,proposed_rate_tzs,profiles!applications_provider_id_fkey(full_name,service_category)").in("job_id",jobs.map(j=>j.id)).order("created_at",{ascending:false}).limit(200);
  if(!active)return;if(error)setError(error.message);else setApps((data||[]) as unknown as Application[]);
 })().catch(()=>{if(active)setError("Could not load applications.");});return()=>{active=false;};},[jobs,supabase]);
 async function action(work:()=>Promise<void>,dialog=false){if(busy)return;setBusy(true);setError("");setDialogError("");try{await work();}catch(e){(dialog?setDialogError:setError)(errorMessage(e));}finally{setBusy(false);}}
 async function createJob(event:FormEvent<HTMLFormElement>){event.preventDefault();const form=event.currentTarget;const fd=new FormData(form);await action(async()=>{
  const {error}=await supabase.rpc("create_job",{p_title:String(fd.get("title")).trim(),p_description:String(fd.get("description")).trim(),p_category:String(fd.get("category")),p_pricing_type:String(fd.get("pricing")),p_amount_tzs:Number(fd.get("amount")),p_lat:profile.lat,p_lng:profile.lng});if(error)throw error;form.reset();setNotice("Your job is posted. Eligible nearby providers can apply.");await refresh();
 });}
 async function inquire(event:FormEvent<HTMLFormElement>){event.preventDefault();const fd=new FormData(event.currentTarget);if(!selected)return;await action(async()=>{
  const {data,error}=await supabase.rpc("start_direct_inquiry",{p_provider_id:selected.id,p_message:String(fd.get("message"))});if(error)throw error;const row=Array.isArray(data)?data[0]:data;if(!row?.conversation_id)throw new Error("Could not open the inquiry. Please refresh.");router.push(`/chat/${row.conversation_id}`);
 },true);}
 async function accept(id:string){await action(async()=>{const {data,error}=await supabase.rpc("accept_application",{p_application_id:id});if(error)throw error;const row=Array.isArray(data)?data[0]:data;if(!row?.conversation_id)throw new Error("Could not open this application.");router.push(`/chat/${row.conversation_id}`);});}
 async function chat(id:string){await action(async()=>{const {data,error}=await supabase.from("conversations").select("id").eq("engagement_id",id).single();if(error)throw error;router.push(`/chat/${data.id}`);});}
 return <>
 <div className="dash-head"><div><div className="eyebrow"><MapPin size={13}/>{profile.area||"Your saved location"}</div><h1>Good day, {profile.full_name.split(" ")[0]}.</h1><p className="muted">Find the right person. Get your day moving.</p></div><span className="pill">Customer workspace</span></div>
 <div className="stats-grid"><div><strong>{jobs.filter(j=>j.status==='open').length}</strong><span>Open jobs</span></div><div><strong>{apps.filter(a=>a.status==='pending').length}</strong><span>New applications</span></div><div><strong>{engagements.filter(e=>['accepted','in_progress'].includes(e.status)).length}</strong><span>Active matches</span></div></div>
 {error&&<div className="error" role="alert">{error}<button className="btn btn-ghost" onClick={()=>action(refresh)} disabled={busy}>Retry</button></div>}{notice&&<div className="success" role="status">{notice}</div>}
 <div className="dash-grid"><div>
 <section className="section card"><div className="section-head"><h2><UserRoundSearch size={18}/> Nearby providers</h2><select aria-label="Filter providers by service" className="select" value={category} onChange={e=>{setCategory(e.target.value);setProviders([]);setLoading(true);}}>{SERVICE_CATEGORIES.map(c=><option key={c}>{c}</option>)}</select></div><p className="muted tiny">Within 15 km. Distances are approximate.</p><div className="list">{loading?<div className="empty" role="status">Finding nearby providers…</div>:providers.length?providers.map(p=><article className="list-card" key={p.id}><div className="row between"><div><h3>{p.full_name}</h3><div className="muted tiny">{p.service_category} · {km(p.dist_meters)}</div></div><span className="price">{money(p.hourly_rate_tzs)} <small>/hr</small></span></div><div className="row"><span className="pill"><Star size={12}/>{p.review_count?`${Number(p.rating_avg).toFixed(1)} (${p.review_count})`:"New provider"}</span>{p.is_verified&&<span className="pill green"><ShieldCheck size={12}/>Verified</span>}</div>{p.bio&&<p className="muted tiny">{p.bio}</p>}<button className="btn btn-primary" disabled={busy} onClick={()=>{setSelected(p);setDialogError("");}}>Send inquiry</button></article>):<div className="empty">No online {category.toLowerCase()} providers nearby yet. Post a job so providers can find you.</div>}</div></section>
 <section className="section card"><div className="section-head"><h2>Applications</h2></div><div className="list">{apps.length?apps.map(a=>{const job=jobs.find(j=>j.id===a.job_id);return <article className="list-card" key={a.id}><div className="row between"><h3>{a.profiles?.full_name||"Provider"}</h3><StatusPill status={a.status}/></div><div className="muted tiny">For: {job?.title||"Your job"}</div>{a.note&&<p className="muted">{a.note}</p>}<div className="row between"><span className="price">{money(a.proposed_rate_tzs??job?.amount_tzs)}{job?.pricing_type==='hourly'&&<small> /hr</small>}</span>{a.status==='pending'&&<button className="btn btn-primary" disabled={busy} onClick={()=>accept(a.id)}>Accept application</button>}</div></article>;}):<div className="empty">Applications to your jobs will appear here.</div>}</div></section>
 <section className="section card"><h2>Your posted jobs</h2><div className="list">{jobs.length?jobs.map(j=><article className="list-card" key={j.id}><div className="row between"><h3>{j.title}</h3><StatusPill status={j.status}/></div><div className="row between"><span>{money(j.amount_tzs)} {j.pricing_type==='hourly'?'/hr':'fixed'}</span>{j.status==='open'&&<button className="btn btn-ghost" disabled={busy} onClick={()=>{setCancelJob(j);setDialogError("");}}>Cancel job</button>}</div></article>):<div className="empty">Your first job starts here.</div>}</div></section>
 </div><div>
 <section className="section card"><div className="section-head"><h2><Plus size={18}/> Post a job</h2></div><form onSubmit={createJob}><div className="field"><label htmlFor="job-title">Job title</label><input id="job-title" className="input" name="title" required minLength={3} maxLength={120} placeholder="Fix a leaking kitchen tap"/></div><div className="field"><label htmlFor="job-description">What needs doing?</label><textarea id="job-description" className="textarea" name="description" required minLength={10} maxLength={4000} placeholder="Describe the job, timing and what the provider should bring."/></div><div className="field"><label htmlFor="job-category">Service</label><select id="job-category" className="select" name="category">{SERVICE_CATEGORIES.map(c=><option key={c}>{c}</option>)}</select></div><div className="form-grid"><div className="field"><label htmlFor="job-pricing">Pricing</label><select id="job-pricing" className="select" name="pricing"><option value="fixed">Fixed price</option><option value="hourly">Per hour</option></select></div><div className="field"><label htmlFor="job-amount">Amount (TZS)</label><input id="job-amount" className="input" type="number" name="amount" min={1} max={100000000} step="0.01" required placeholder="20000"/></div></div><p className="muted tiny">Posted at your saved location. Update your location first if the job is somewhere else.</p><button className="btn btn-primary full" disabled={busy}>Post job</button></form></section>
 <section className="section card"><h2>Matches & history</h2><div className="list">{engagements.length?engagements.map(e=><article className="list-card" key={e.id}><div className="row between"><h3>{e.profiles?.full_name||"Provider"}</h3><StatusPill status={e.status}/></div><span className="price">{money(e.agreed_amount_tzs)} {e.pricing_type==='hourly'?'/hr':'fixed'}</span><div className="row"><button className="btn btn-ghost" disabled={busy} onClick={()=>chat(e.id)}><MessageCircle size={15}/>Chat</button><button className="btn btn-secondary" onClick={()=>router.push(`/match/${e.id}`)}>Open match</button></div></article>):<div className="empty">Your inquiries and hired providers appear here.</div>}</div></section>
 </div></div>
 {selected&&<ActionDialog title={`Contact ${selected.full_name}`} busy={busy} onClose={()=>setSelected(null)} onSubmit={inquire} submitLabel="Send inquiry"><p className="muted">{money(selected.hourly_rate_tzs)} per hour. This starts a conversation, with no automatic payment.</p><div className="field"><label htmlFor="inquiry">Your message</label><textarea autoFocus id="inquiry" name="message" className="textarea" required maxLength={2000} defaultValue="Hi, are you available for a job near me?"/></div>{dialogError&&<div className="error" role="alert">{dialogError}</div>}</ActionDialog>}
 {cancelJob&&<ActionDialog title="Cancel this job?" busy={busy} onClose={()=>setCancelJob(null)} submitLabel="Confirm cancellation" onSubmit={event=>{event.preventDefault();void action(async()=>{const {error}=await supabase.rpc("cancel_job",{p_job_id:cancelJob.id});if(error)throw error;setCancelJob(null);await refresh();},true);}}><p>{cancelJob.title}</p><p className="muted">Pending applications will be closed. You can post a new job later.</p>{dialogError&&<div className="error">{dialogError}</div>}</ActionDialog>}
 </>;
}
