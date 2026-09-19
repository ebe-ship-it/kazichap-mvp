"use client";

import { FormEvent, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowRight } from "lucide-react";
import { createClient } from "@/lib/supabase/client";
import { normalizePhone, errorMessage } from "@/lib/validation";
import { SERVICE_CATEGORIES } from "@/lib/constants";

export function SignupForm({ role }: { role: "customer" | "provider" }) {
  const router = useRouter();
  const supabase = createClient();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [success, setSuccess] = useState("");

  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault();
    if (busy) return;
    setBusy(true); setError(""); setSuccess("");
    const fd = new FormData(e.currentTarget);
    const email = String(fd.get("email") || "").trim();
    const password = String(fd.get("password") || "");
    try {
    const phone = normalizePhone(String(fd.get("phone") || ""));
    if (!phone) throw new Error("Enter a valid Tanzanian mobile number, such as 0712345678 or +255712345678.");
    const metadata = {
      full_name: String(fd.get("full_name") || "").trim(),
      phone,
      role,
      service_category: role === "provider" ? String(fd.get("service_category") || "") : null,
      hourly_rate_tzs: role === "provider" ? Number(fd.get("hourly_rate_tzs") || 0) : null,
      bio: role === "provider" ? String(fd.get("bio") || "") : null,
    };

    const { data, error: signError } = await supabase.auth.signUp({
      email,
      password,
      options: { data: metadata, emailRedirectTo: `${window.location.origin}/auth/confirm` },
    });

    if (signError) { setError(signError.message); setBusy(false); return; }
    if (data.session) {
      router.push("/onboarding/location");
      router.refresh();
    } else {
      setSuccess("Account created. Check your email to confirm it, then log in to continue.");
      setBusy(false);
    }
    } catch (err) {setError(errorMessage(err));} finally {setBusy(false);}
  }

  return (
    <form className="card form-card" onSubmit={submit}>
      <h2>{role === "provider" ? "Create worker profile" : "Create customer account"}</h2>
      <p>{role === "provider" ? "Tell customers what you do and what you charge." : "Post jobs and hire nearby providers."}</p>
      <div className="form-grid">
        <div className="field"><label htmlFor="signup-full_name">Full name</label><input id="signup-full_name" className="input" name="full_name" autoComplete="name" minLength={2} maxLength={100} required placeholder="Asha M." /></div>
        <div className="field"><label htmlFor="signup-phone">Phone number</label><input id="signup-phone" className="input" name="phone" type="tel" autoComplete="tel" required placeholder="+255 7xx xxx xxx" /></div>
      </div>
      <div className="field"><label htmlFor="signup-email">Email</label><input id="signup-email" className="input" name="email" autoComplete="email" type="email" required placeholder="you@example.com" /></div>
      <div className="field"><label htmlFor="signup-password">Password</label><input id="signup-password" className="input" name="password" maxLength={72} autoComplete="new-password" type="password" minLength={8} required placeholder="At least 8 characters" /></div>
      {role === "provider" && (
        <>
          <div className="form-grid">
            <div className="field"><label htmlFor="signup-service_category">Service category</label><select id="signup-service_category" className="select" name="service_category" required defaultValue=""><option value="" disabled>Select service</option>{SERVICE_CATEGORIES.map(x => <option key={x}>{x}</option>)}</select></div>
            <div className="field"><label htmlFor="signup-hourly_rate_tzs">Hourly rate (TZS)</label><input id="signup-hourly_rate_tzs" className="input" name="hourly_rate_tzs" type="number" min="1" max="100000000" step="0.01" required placeholder="15000" /></div>
          </div>
          <div className="field"><label htmlFor="signup-bio">Short bio</label><textarea id="signup-bio" className="textarea" name="bio" maxLength={1000} required placeholder="Example: Electrician with 5 years of residential wiring experience in Dar es Salaam." /></div>
        </>
      )}
      {error && <div className="error" role="alert">{error}</div>}
      {success && <div className="success" role="status">{success}</div>}
      <button className="btn btn-primary full" disabled={busy}>{busy ? "Creating account…" : <>Continue <ArrowRight size={17}/></>}</button>
    </form>
  );
}
