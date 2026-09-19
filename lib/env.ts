export function hasSupabaseConfig(): boolean {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key || /YOUR_PROJECT/i.test(url) || /xxx|YOUR_/i.test(key)) return false;
  try { return new URL(url).protocol === "https:" && (key.startsWith("sb_publishable_")); }
  catch { return false; }
}

export function supabaseConfig() {
  if (!hasSupabaseConfig()) throw new Error("KaziChap setup is incomplete. Configure the Supabase environment variables and redeploy.");
  return { url: process.env.NEXT_PUBLIC_SUPABASE_URL!, key: process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY! };
}
