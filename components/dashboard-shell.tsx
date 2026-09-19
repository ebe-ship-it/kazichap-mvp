"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";
import Link from "next/link";
import { LogOut } from "lucide-react";
import { Logo } from "./logo";
import { createClient } from "@/lib/supabase/client";
import { CustomerDashboard } from "./customer-dashboard";
import { ProviderDashboard } from "./provider-dashboard";

export type Profile = {
  id: string; full_name: string; role: "customer"|"provider"; service_category: string|null;
  hourly_rate_tzs: number|null; bio: string|null; is_online: boolean; is_verified: boolean;
  lat: number|null; lng: number|null; area: string|null; rating_avg: number; review_count: number;
};

export function DashboardShell() {
  const supabase = createClient();
  const router = useRouter();
  const [profile, setProfile] = useState<Profile|null>(null);
  const [error, setError] = useState("");

  useEffect(() => { (async()=>{
    const { data: { user } } = await supabase.auth.getUser();
    if (!user) { router.replace("/login"); return; }
    const { data, error } = await supabase.rpc("get_my_profile");
    if (error) { setError(error.message); return; }
    const row = Array.isArray(data) ? data[0] : data;
    if (!row) { setError("Profile not found."); return; }
    if (row.lat == null || row.lng == null) { router.replace("/onboarding/location"); return; }
    setProfile(row as Profile);
  })().catch(()=>setError("Could not load your account. Check your connection.")); }, [router, supabase]);

  async function logout() {
    try {
      if (profile?.role === "provider") {
        const {error} = await supabase.rpc("set_online", {p_online:false});
        if (error) {setError("Could not set you offline. Try again before signing out.");return;}
      }
      const {error} = await supabase.auth.signOut();
      if (error) {setError(error.message);return;}
      router.push("/"); router.refresh();
    } catch {setError("Could not sign out. Check your connection.");}
  }

  if (error) return <div className="shell"><div className="error" role="alert">{error}</div><button className="btn btn-primary" onClick={()=>window.location.reload()}>Retry</button><Link href="/login" className="btn btn-ghost">Login</Link></div>;
  if (!profile) return <div className="shell" style={{padding:40}}><div className="muted">Loading your KaziChap dashboard…</div></div>;

  return <main className="shell dashboard">
    <header className="topbar"><Logo /><div className="row"><Link href="/onboarding/location" className="btn btn-ghost">Update location</Link><button className="btn btn-ghost" onClick={logout}><LogOut size={16}/> Logout</button></div></header>
    {profile.role === "customer" ? <CustomerDashboard profile={profile}/> : <ProviderDashboard profile={profile} onProfile={setProfile}/>} 
  </main>;
}
