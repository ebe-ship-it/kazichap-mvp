import { hasSupabaseConfig } from "@/lib/env";
import SetupPage from "@/app/setup/page";
import { AuthShell } from "@/components/auth-shell";
import { SignupForm } from "@/components/signup-form";

export default function CustomerSignup() {
  if (!hasSupabaseConfig()) return <SetupPage/>;
  return <AuthShell headline="Hire nearby. Move faster." copy="Post a job, browse providers around you, chat, track the match and close the job in one flow."><SignupForm role="customer" /></AuthShell>;
}
