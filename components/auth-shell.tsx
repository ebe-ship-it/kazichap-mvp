import Link from "next/link";
import { Logo } from "./logo";

export function AuthShell({ children, headline, copy }: { children: React.ReactNode; headline: string; copy: string }) {
  return (
    <main className="auth-wrap">
      <section className="auth-art">
        <Logo />
        <div>
          <h1>{headline}</h1>
          <p>{copy}</p>
        </div>
        <Link href="/" className="muted">← Back to start</Link>
      </section>
      <section className="auth-panel">{children}</section>
    </main>
  );
}
