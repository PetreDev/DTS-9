"use client";

import { useRouter } from "next/navigation";
import { signOut, useSession } from "@/lib/auth/client";
import { useState } from "react";
import { trackAuthEvent } from "@/features/auth/actions";

export function SignOutButton() {
  const router = useRouter();
  const { data: session } = useSession();
  const [isLoading, setIsLoading] = useState(false);

  const handleSignOut = async () => {
    setIsLoading(true);
    
    // Track logout event before signing out
    await trackAuthEvent("logout", session?.user?.email ?? "unknown");
    
    await signOut();
    router.push("/login");
    router.refresh();
  };

  return (
    <button
      onClick={handleSignOut}
      disabled={isLoading}
      className="text-sm text-text-muted hover:text-text px-3 py-1.5 rounded-lg hover:bg-bg-card transition-colors disabled:opacity-50"
    >
      {isLoading ? "..." : "Sign out"}
    </button>
  );
}
