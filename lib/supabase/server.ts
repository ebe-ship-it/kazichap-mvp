import { createServerClient } from "@supabase/ssr";
import { supabaseConfig } from "@/lib/env";
import { cookies } from "next/headers";

export async function createClient() {
  const cookieStore = await cookies();
  const { url, key } = supabaseConfig();

  return createServerClient(
    url,
    key,
    {
      cookies: {
        getAll() {
          return cookieStore.getAll();
        },
        setAll(cookiesToSet) {
          try {
            cookiesToSet.forEach(({ name, value, options }) => cookieStore.set(name, value, options));
          } catch {
            // A Server Component cannot always write cookies. proxy.ts refreshes them.
          }
        },
      },
    }
  );
}
