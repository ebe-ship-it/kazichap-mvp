import { type NextRequest, NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";

export async function GET(request: NextRequest) {
  const token_hash = request.nextUrl.searchParams.get("token_hash");
  const type = request.nextUrl.searchParams.get("type");
  if (token_hash && (type === "email" || type === "recovery" || type === "signup")) {
    try {
      const supabase = await createClient();
      const { error } = await supabase.auth.verifyOtp({ token_hash, type });
      if (!error) return NextResponse.redirect(new URL(type === "recovery" ? "/reset-password" : "/onboarding/location", request.url));
    } catch { /* Show a retry path without exposing tokens or error internals. */ }
  }
  return NextResponse.redirect(new URL("/auth/error", request.url));
}
