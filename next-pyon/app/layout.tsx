import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "next-pyon",
  description: "Next.js app running on Cloudflare with OpenNext",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="ja">
      <body className="antialiased">{children}</body>
    </html>
  );
}
