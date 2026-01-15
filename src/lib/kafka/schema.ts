/**
 * Simple Avro schema for interaction events
 */

export const INTERACTION_EVENT_SCHEMA = {
  type: "record",
  name: "InteractionEvent",
  namespace: "com.taskflow.events",
  fields: [
    { name: "id", type: "string" },
    { name: "action", type: "string" },
    { name: "who", type: "string" },
    { name: "what", type: "string" },
    { name: "time", type: "string" },
  ],
} as const;

export const TOPIC_NAME = "taskflow-interactions";
