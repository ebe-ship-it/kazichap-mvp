"use client";
import { useEffect } from "react";
// Polling also recovers changes missed during a temporary Realtime disconnect.
export function useRefresh(load: () => Promise<unknown>, onError: (message: string) => void, milliseconds = 10000) {
  useEffect(() => {
    let busy = false;
    let active = true;
    const refresh = async () => {
      if (busy || !active || document.visibilityState === "hidden") return;
      busy = true;
      try { await load(); }
      catch { if (active) onError("Could not refresh. Check your connection and try again."); }
      finally { busy = false; }
    };
    void refresh();
    const timer = window.setInterval(refresh, milliseconds);
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", refresh);
    return () => { active = false; window.clearInterval(timer); window.removeEventListener("focus", refresh); document.removeEventListener("visibilitychange", refresh); };
  }, [load, onError, milliseconds]);
}
