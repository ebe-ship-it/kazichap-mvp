import { hasSupabaseConfig } from "@/lib/env";
import SetupPage from "@/app/setup/page";
import { DashboardShell } from "@/components/dashboard-shell";

export default function DashboardPage() { if (!hasSupabaseConfig()) return <SetupPage/>; return <DashboardShell />; }
