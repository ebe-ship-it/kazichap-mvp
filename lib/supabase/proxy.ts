import { createServerClient } from "@supabase/ssr";
import { NextResponse, type NextRequest } from "next/server";
import { hasSupabaseConfig, supabaseConfig } from "@/lib/env";

const protectedRoutes = ["/dashboard", "/onboarding", "/chat", "/match", "/payment", "/reset-password"];
export async function updateSession(request: NextRequest) {
  const pathname = request.nextUrl.pathname;
  const protectedRoute = protectedRoutes.some(path => pathname === path || pathname.startsWith(path + "/"));
  if (!hasSupabaseConfig()) {
    return NextResponse.redirect(new URL("/setup", request.url));
  }
  let response = NextResponse.next({ request });
  const { url, key } = supabaseConfig();
  const supabase = createServerClient(url, key, {
    cookies: {
      getAll: () => request.cookies.getAll(),
      setAll(cookies) {
        cookies.forEach(({ name, value }) => request.cookies.set(name, value));
        response = NextResponse.next({ request });
        cookies.forEach(({ name, value, options }) => response.cookies.set(name, value, options));
      },
    },
  });
  try {
    const { data, error } = await supabase.auth.getClaims();
    if (protectedRoute && (error || !data?.claims)) {
      const destination = new URL("/login", request.url);
      destination.searchParams.set("next", pathname + request.nextUrl.search);
      const redirect = NextResponse.redirect(destination);
      response.cookies.getAll().forEach(cookie => redirect.cookies.set(cookie));
      redirect.headers.set("Cache-Control", "private, no-store");
      return redirect;
    }
  } catch {
    if (protectedRoute) return NextResponse.redirect(new URL("/auth/error", request.url));
  }
  response.headers.set("Cache-Control", "private, no-store");
  return response;
}
