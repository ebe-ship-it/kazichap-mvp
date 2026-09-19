export const SERVICE_CATEGORIES = [
  "Plumber",
  "Electrician",
  "Carpenter",
  "Painter",
  "Cleaner",
  "Chef",
  "Tutor",
  "Relief Teacher",
  "Nurse",
  "Doctor",
  "Mechanic",
  "Delivery / Errands",
  "Other",
] as const;

export function money(value?: number | null) {
  if (value == null) return "—";
  return new Intl.NumberFormat("en-TZ", { maximumFractionDigits: 2 }).format(value) + " TZS";
}

export function km(meters?: number | null) {
  if (meters == null) return "distance unavailable";
  if (meters === 0) return "less than 500 m away";
  if (meters < 1000) return `${Math.round(meters)} m away`;
  return `${(meters / 1000).toFixed(1)} km away`;
}
