"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { trackPageView } from "../actions";

interface PageViewTrackerProps {
  userEmail?: string | null;
}

/**
 * Client component that tracks page views on route changes
 */
export function PageViewTracker({ userEmail }: PageViewTrackerProps) {
  const pathname = usePathname();
  const lastTrackedPath = useRef<string | null>(null);

  useEffect(() => {
    // Only track if the path has changed
    if (pathname && pathname !== lastTrackedPath.current) {
      lastTrackedPath.current = pathname;
      trackPageView(pathname, userEmail ?? null);
    }
  }, [pathname, userEmail]);

  return null;
}
