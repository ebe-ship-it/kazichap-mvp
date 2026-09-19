import { type NextRequest } from "next/server";
import { updateSession } from "@/lib/supabase/proxy";
export async function proxy(request: NextRequest) { return updateSession(request); }
export const config = {
  matcher: ["/dashboard/:path*", "/onboarding/:path*", "/chat/:path*", "/match/:path*", "/payment/:path*", "/signup/:path*", "/login", "/forgot-password", "/reset-password", "/auth/confirm", "/auth/callback"],
};
