import type { Metadata } from "next";
import { headers } from "next/headers";
import { auth } from "@/lib/auth";
import { PageViewTracker } from "@/features/tracking";
import "./globals.css";

export const metadata: Metadata = {
  title: "Taskflow",
  description: "A minimal todo app that gets out of your way",
};

export default async function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  return (
    <html lang="en">
      <body className="antialiased min-h-screen">
        <PageViewTracker userEmail={session?.user?.email} />
        {children}
      </body>
    </html>
  );
}
