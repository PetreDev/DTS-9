/**
 * Simple types for Kafka interaction events
 */

export type Action = "view" | "login" | "register" | "logout" | "create" | "complete" | "delete";

export interface InteractionEvent {
  id: string;
  action: Action;
  who: string;
  what: string;
  time: string;
}

export interface TrackEventOptions {
  who?: string;
  what?: string;
}
