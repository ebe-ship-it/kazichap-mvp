import { hasSupabaseConfig } from "@/lib/env";
import SetupPage from "@/app/setup/page";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/signup-form";

export default function ProviderSignup() {
  if (!hasSupabaseConfig()) return <SetupPage/>;
  return <AuthShell headline="Turn your skill into nearby work." copy="Set your service, hourly rate and availability. KaziChap shows you relevant jobs around you."><SignupForm role="provider" /></AuthShell>;
}
