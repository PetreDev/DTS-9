"use server";

import { trackEvent } from "@/lib/kafka";
import type { Action } from "@/lib/kafka";

/**
 * Server action to track authentication events
 */
export async function trackAuthEvent(
  action: Extract<Action, "login" | "register" | "logout">,
  userEmail: string
): Promise<void> {
  await trackEvent(action, {
    who: userEmail,
    what: action,
  });
}
