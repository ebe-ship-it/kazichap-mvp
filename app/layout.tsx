import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "KaziChap — Quick Work",
  description: "Find trusted work and trusted workers near you.",
  manifest: "/manifest.json",
  icons: { icon: "/icon-512.png" },
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en">
      <body>{children}</body>
    </html>
  );
}
