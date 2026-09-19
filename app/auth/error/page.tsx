import Link from "next/link";
import { AuthShell } from "@/components/auth-shell";
export default function AuthError() {
  return <AuthShell headline="Let’s get you back in." copy="Your account stays safe when a sign-in link expires."><section className="card form-card"><h2>This link could not be verified</h2><p>It may have expired or already been used. If you have confirmed your account, sign in. Otherwise, request a fresh confirmation email from the login page.</p><Link className="btn btn-primary full" href="/login">Return to login</Link><Link className="btn btn-ghost full" href="/forgot-password" style={{marginTop:12}}>Reset password</Link></section></AuthShell>;
}
