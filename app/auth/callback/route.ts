import { type NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { safeRedirect } from "@/lib/validation";
export async function GET(request: NextRequest) {
  const code = request.nextUrl.searchParams.get("code");
  if (code) {
    try {
      const supabase = await createClient();
      const { error } = await supabase.auth.exchangeCodeForSession(code);
      if (!error) return NextResponse.redirect(new URL(safeRedirect(request.nextUrl.searchParams.get("next")), request.url));
    } catch { /* Invalid or expired link. */ }
  }
  return NextResponse.redirect(new URL("/auth/error", request.url));
}
