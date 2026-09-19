export function validCoordinates(lat: number, lng: number): boolean {
  return Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
}

export function normalizePhone(input: string): string | null {
  const value = input.replace(/[\s()-]/g, "");
  const normalized = value.startsWith("0") ? "+255" + value.slice(1) : value.startsWith("255") ? "+" + value : value;
  return /^\+255[67]\d{8}$/.test(normalized) ? normalized : null;
}

export function positiveAmount(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !/^\d+(\.\d{1,2})?$/.test(value.trim())) return null;
  const amount = Number(value);
  return Number.isFinite(amount) && amount > 0 && amount <= 100_000_000 && Math.abs(amount * 100 - Math.round(amount * 100)) < 0.00001 ? amount : null;
}

export function safeRedirect(value: string | null, fallback = "/dashboard"): string {
  if (!value || !value.startsWith("/") || value.startsWith("//") || /[\\\r\n]/.test(value)) return fallback;
  try {
    const decoded = decodeURIComponent(value);
    if (decoded.startsWith("//") || /[\\\r\n]/.test(decoded)) return fallback;
    const url = new URL(value, "https://kazichap.invalid");
    return url.origin === "https://kazichap.invalid" ? url.pathname + url.search : fallback;
  } catch { return fallback; }
}

export function paymentTotal(rate: number, pricing: string, minutes: number | null): number | null {
  if (positiveAmount(rate) === null) return null;
  if (pricing === "fixed") return rate;
  if (pricing !== "hourly" || minutes == null || !Number.isInteger(minutes) || minutes < 1 || minutes > 43200) return null;
  return Math.round(rate * minutes / 60 * 100) / 100;
}

export function errorMessage(error: unknown): string {
  return error && typeof error === "object" && "message" in error && typeof error.message === "string"
    ? error.message : "Something went wrong. Check your connection and try again.";
}
