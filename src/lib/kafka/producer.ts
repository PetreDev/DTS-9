import { Kafka, Producer, logLevel } from "kafkajs";
import { SchemaRegistry, SchemaType } from "@kafkajs/confluent-schema-registry";
import { randomUUID } from "crypto";
import { INTERACTION_EVENT_SCHEMA, TOPIC_NAME } from "./schema";
import type { Action, InteractionEvent, TrackEventOptions } from "./types";

// Configuration from environment
const KAFKA_BROKERS = (process.env.KAFKA_BROKERS || "localhost:9092").split(",");
const SCHEMA_REGISTRY_URL = process.env.SCHEMA_REGISTRY_URL || "http://localhost:8081";

// Singleton instances
let kafka: Kafka | null = null;
let producer: Producer | null = null;
let registry: SchemaRegistry | null = null;
let schemaId: number | null = null;
let isConnected = false;
let isConnecting = false;

function getKafka(): Kafka {
  if (!kafka) {
    kafka = new Kafka({
      clientId: "taskflow-app",
      brokers: KAFKA_BROKERS,
      logLevel: logLevel.WARN,
      retry: {
        initialRetryTime: 100,
        retries: 5,
      },
    });
  }
  return kafka;
}

function getRegistry(): SchemaRegistry {
  if (!registry) {
    registry = new SchemaRegistry({
      host: SCHEMA_REGISTRY_URL,
    });
  }
  return registry;
}

async function ensureSchemaRegistered(): Promise<number> {
  if (schemaId) return schemaId;

  const reg = getRegistry();
  const { id } = await reg.register({
    type: SchemaType.AVRO,
    schema: JSON.stringify(INTERACTION_EVENT_SCHEMA),
  }, {
    subject: `${TOPIC_NAME}-value`,
  });

  schemaId = id;
  return id;
}

async function connect(): Promise<void> {
  if (isConnected || isConnecting) return;

  isConnecting = true;

  try {
    const k = getKafka();
    producer = k.producer();
    await producer.connect();
    await ensureSchemaRegistered();
    isConnected = true;
  } catch (error) {
    console.error("[Kafka] Failed to connect:", error);
    isConnected = false;
    throw error;
  } finally {
    isConnecting = false;
  }
}

async function disconnect(): Promise<void> {
  if (producer && isConnected) {
    await producer.disconnect();
    isConnected = false;
    producer = null;
  }
}

/**
 * Format timestamp as readable string
 */
function formatTime(): string {
  return new Date().toLocaleString("en-US", {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

/**
 * Track an interaction event by sending it to Kafka
 */
export async function trackEvent(
  action: Action,
  options: TrackEventOptions = {}
): Promise<void> {
  // Skip in development if Kafka is not configured
  if (process.env.DISABLE_KAFKA === "true") {
    console.log(`[Kafka] Event skipped (disabled): ${action}`, options);
    return;
  }

  const eventId = randomUUID();
  const event: InteractionEvent = {
    id: eventId,
    action,
    who: options.who || "anonymous",
    what: options.what || "-",
    time: formatTime(),
  };

  try {
    if (!isConnected) {
      await connect();
    }

    if (!producer || !schemaId) {
      throw new Error("Kafka producer not initialized");
    }

    const reg = getRegistry();
    const encodedValue = await reg.encode(schemaId, event);

    await producer.send({
      topic: TOPIC_NAME,
      messages: [
        {
          key: eventId,
          value: encodedValue,
        },
      ],
    });

    console.log(`[Kafka] ${action}: ${event.who} -> ${event.what}`);
  } catch (error) {
    // Log but don't throw - we don't want tracking to break the app
    console.error(`[Kafka] Failed to send event: ${action}`, error);
  }
}

// Graceful shutdown
if (typeof process !== "undefined") {
  const signals: NodeJS.Signals[] = ["SIGINT", "SIGTERM"];
  signals.forEach((signal) => {
    process.on(signal, async () => {
      await disconnect();
      process.exit(0);
    });
  });
}

export { connect, disconnect };
