export function StatusPill({ status }: { status: string }) {
  const good = ["paid", "completed", "accepted", "in_progress"].includes(status);
  return <span className={`pill ${good ? "green" : "red"}`}>{status.replaceAll("_", " ")}</span>;
}
