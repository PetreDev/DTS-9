import { headers } from "next/headers";
import { redirect } from "next/navigation";
import { auth } from "@/lib/auth";
import Link from "next/link";

export default async function HomePage() {
  const session = await auth.api.getSession({
    headers: await headers(),
  });

  if (session) {
    redirect("/todos");
  }

  return (
    <div className="min-h-screen bg-bg relative overflow-hidden">
      {/* Background grid pattern */}
      <div className="absolute inset-0 grid-pattern opacity-30" />
      
      {/* Gradient orbs */}
      <div className="absolute top-1/4 left-1/4 w-96 h-96 bg-accent/10 rounded-full blur-3xl" />
      <div className="absolute bottom-1/4 right-1/4 w-96 h-96 bg-orange-500/5 rounded-full blur-3xl" />
      
      {/* Content */}
      <div className="relative z-10 min-h-screen flex flex-col items-center justify-center px-4">
        <div className="text-center max-w-2xl animate-fade-in">
          {/* Logo/Icon */}
          <div className="mb-8 inline-flex items-center justify-center w-16 h-16 rounded-2xl bg-bg-card border border-border">
            <svg
              className="w-8 h-8 text-accent"
              fill="none"
              viewBox="0 0 24 24"
              stroke="currentColor"
              strokeWidth={2}
            >
              <path
                strokeLinecap="round"
                strokeLinejoin="round"
                d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4"
              />
            </svg>
          </div>

          {/* Heading */}
          <h1 className="text-5xl sm:text-6xl font-bold tracking-tight mb-4">
            <span className="gradient-text">Taskflow</span>
          </h1>
          
          <p className="text-xl text-text-muted mb-12 max-w-md mx-auto">
            A minimal todo app that gets out of your way. 
            Focus on what matters.
          </p>

          {/* CTA buttons */}
          <div className="flex flex-col sm:flex-row gap-4 justify-center">
            <Link
              href="/register"
              className="group px-8 py-3 bg-accent text-white font-medium rounded-xl hover:bg-accent-hover transition-all duration-200 glow"
            >
              Get started
              <span className="inline-block ml-2 transition-transform group-hover:translate-x-1">→</span>
            </Link>
            <Link
              href="/login"
              className="px-8 py-3 bg-bg-card text-text border border-border font-medium rounded-xl hover:border-border-hover hover:bg-bg-elevated transition-all duration-200"
            >
              Sign in
            </Link>
          </div>
        </div>

        {/* Feature highlights */}
        <div className="mt-24 grid grid-cols-1 sm:grid-cols-3 gap-6 max-w-3xl stagger-children">
          <div className="p-6 rounded-xl bg-bg-card/50 border border-border backdrop-blur-sm">
            <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center mb-4">
              <svg className="w-5 h-5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
            </div>
            <h3 className="font-semibold mb-2">Lightning fast</h3>
            <p className="text-sm text-text-muted">Built with Next.js 16 and server actions for instant updates.</p>
          </div>

          <div className="p-6 rounded-xl bg-bg-card/50 border border-border backdrop-blur-sm">
            <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center mb-4">
              <svg className="w-5 h-5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 15v2m-6 4h12a2 2 0 002-2v-6a2 2 0 00-2-2H6a2 2 0 00-2 2v6a2 2 0 002 2zm10-10V7a4 4 0 00-8 0v4h8z" />
              </svg>
            </div>
            <h3 className="font-semibold mb-2">Secure by default</h3>
            <p className="text-sm text-text-muted">Your data stays private with session-based auth.</p>
          </div>

          <div className="p-6 rounded-xl bg-bg-card/50 border border-border backdrop-blur-sm">
            <div className="w-10 h-10 rounded-lg bg-accent/10 flex items-center justify-center mb-4">
              <svg className="w-5 h-5 text-accent" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M4 7v10c0 2.21 3.582 4 8 4s8-1.79 8-4V7M4 7c0 2.21 3.582 4 8 4s8-1.79 8-4M4 7c0-2.21 3.582-4 8-4s8 1.79 8 4" />
              </svg>
            </div>
            <h3 className="font-semibold mb-2">PostgreSQL backed</h3>
            <p className="text-sm text-text-muted">Reliable data storage with Drizzle ORM.</p>
          </div>
        </div>
      </div>
    </div>
  );
}
