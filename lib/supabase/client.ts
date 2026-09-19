import { createBrowserClient } from "@supabase/ssr";
import { supabaseConfig } from "@/lib/env";
let browserClient: ReturnType<typeof createBrowserClient> | undefined;
export function createClient() {
  const { url, key } = supabaseConfig();
  return browserClient ??= createBrowserClient(url, key);
}
