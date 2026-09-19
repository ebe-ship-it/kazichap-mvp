import Link from "next/link";
import { Logo } from "@/components/logo";
export default function SetupPage() {
 return <main className="shell"><header className="topbar"><Logo/></header><section className="hero"><div className="card form-card"><div className="eyebrow">KaziChap</div><h2 style={{marginTop:20}}>Getting ready to open.</h2><p>Account access is not available yet. Please try again once setup is complete.</p><Link className="btn btn-primary full" href="/">Back to home</Link><details style={{marginTop:24}}><summary>Are you setting up this app?</summary><p className="muted">Follow README.md to add the Supabase URL and publishable key to your environment, run the database setup, then restart locally or redeploy on Vercel.</p></details></div></section></main>;
}
