"use client";
import Link from "next/link";
export default function ErrorPage({reset}:{reset:()=>void}) {
 return <main className="shell hero"><section className="card form-card"><h2>Something didn’t load.</h2><p>Please check your connection and try again.</p><button className="btn btn-primary full" onClick={reset}>Try again</button><Link href="/dashboard" className="btn btn-ghost full" style={{marginTop:12}}>Return to dashboard</Link></section></main>;
}
