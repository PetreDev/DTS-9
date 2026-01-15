"use server";

import { trackEvent } from "@/lib/kafka";

/**
 * Server action to track page view events
 */
export async function trackPageView(
  pagePath: string,
  userEmail: string | null
): Promise<void> {
  await trackEvent("view", {
    who: userEmail || "anonymous",
    what: pagePath,
  });
}
