# Kafka Workflow: Website to Cassandra

This document explains how user interaction events flow from the Next.js website through Kafka to the Cassandra database.

## Overview

The system tracks user interactions (page views, logins, todo operations) and stores them in Cassandra for analytics. The data flows through the following pipeline:

```
Website → Server Actions → Kafka Producer → Kafka Topic → Kafka Connect → Cassandra
```

## Architecture Components

### 1. **Kafka Infrastructure** (Docker Compose)

- **Kafka Broker**: Message queue that stores events
- **Schema Registry**: Manages Avro schemas for data validation
- **Kafka Connect**: Connects Kafka to external systems (Cassandra)
- **Cassandra**: NoSQL database for storing interaction events

### 2. **Application Components**

- **Client Components**: React components that trigger events
- **Server Actions**: Next.js server actions that handle business logic and tracking
- **Kafka Producer**: Library that sends events to Kafka
- **Cassandra Sink Connector**: Automatically writes Kafka messages to Cassandra

---

## Data Flow Step-by-Step

### Step 1: User Interaction on Website

Users interact with the website in various ways:

- **Page Views**: Automatically tracked when navigating between pages
- **Authentication**: Login, register, logout events
- **Todo Operations**: Create, complete, delete todos

**Example: Page View Tracking**

```typescript
// src/features/tracking/components/page-view-tracker.tsx
"use client";

import { useEffect, useRef } from "react";
import { usePathname } from "next/navigation";
import { trackPageView } from "../actions";

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
```

**Example: Todo Creation Tracking**

```typescript
// src/features/todos/actions.ts
export async function createTodoAction(input: CreateTodoInput) {
  // ... business logic ...
  const todo = await todoService.create(user.id, result.data.title);

  // Track todo creation event
  await trackEvent("create", {
    who: user.email,
    what: result.data.title,
  });

  return { success: true, data: { id: todo.id } };
}
```

### Step 2: Server Actions Call Kafka Producer

Server actions call the `trackEvent` function from the Kafka library:

```typescript
// src/features/tracking/actions.ts
"use server";

import { trackEvent } from "@/lib/kafka";

export async function trackPageView(
  pagePath: string,
  userEmail: string | null
): Promise<void> {
  await trackEvent("view", {
    who: userEmail || "anonymous",
    what: pagePath,
  });
}
```

### Step 3: Kafka Producer Sends Event to Kafka

The `trackEvent` function in the Kafka producer:

1. **Creates the event object** with required fields
2. **Connects to Kafka** (lazy connection on first use)
3. **Registers/retrieves Avro schema** from Schema Registry
4. **Encodes the event** using Avro schema
5. **Sends the message** to the Kafka topic

```typescript
// src/lib/kafka/producer.ts
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
    // Lazy connection - connects on first use
    if (!isConnected) {
      await connect();
    }

    if (!producer || !schemaId) {
      throw new Error("Kafka producer not initialized");
    }

    // Encode event using Avro schema
    const reg = getRegistry();
    const encodedValue = await reg.encode(schemaId, event);

    // Send to Kafka topic
    await producer.send({
      topic: TOPIC_NAME, // "taskflow-interactions"
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
```

**Event Schema (Avro)**

```typescript
// src/lib/kafka/schema.ts
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
```

**Event Types**

```typescript
// src/lib/kafka/types.ts
export type Action =
  | "view"
  | "login"
  | "register"
  | "logout"
  | "create"
  | "complete"
  | "delete";

export interface InteractionEvent {
  id: string;
  action: Action;
  who: string;
  what: string;
  time: string;
}
```

### Step 4: Kafka Stores the Event

The event is stored in the Kafka topic `taskflow-interactions`:

- **Topic**: `taskflow-interactions`
- **Partitions**: 3 (for parallel processing)
- **Replication Factor**: 1 (single broker setup)
- **Retention**: 7 days
- **Key**: Event ID (UUID)
- **Value**: Avro-encoded event data

### Step 5: Kafka Connect Sink Connector Reads from Topic

Kafka Connect automatically reads messages from the topic and writes them to Cassandra.

**Connector Configuration**

```json
// kafka/connect/cassandra-sink.json
{
  "name": "cassandra-sink-interactions",
  "config": {
    "connector.class": "io.confluent.connect.cassandra.CassandraSinkConnector",
    "tasks.max": "1",
    "topics": "taskflow-interactions",
    "cassandra.contact.points": "cassandra",
    "cassandra.port": "9042",
    "cassandra.keyspace": "taskflow",
    "cassandra.local.datacenter": "dc1",
    "cassandra.consistency.level": "LOCAL_ONE",
    "cassandra.write.mode": "Insert",
    "pk.mode": "record_key",
    "pk.fields": "id",
    "auto.create": "false",
    "confluent.topic.bootstrap.servers": "kafka:29092",
    "key.converter": "org.apache.kafka.connect.storage.StringConverter",
    "value.converter": "io.confluent.connect.avro.AvroConverter",
    "value.converter.schema.registry.url": "http://schema-registry:8081",
    "transforms": "routeToTable,extractKey",
    "transforms.routeToTable.type": "org.apache.kafka.connect.transforms.RegexRouter",
    "transforms.routeToTable.regex": "taskflow-interactions",
    "transforms.routeToTable.replacement": "interactions",
    "transforms.extractKey.type": "org.apache.kafka.connect.transforms.ValueToKey",
    "transforms.extractKey.fields": "id"
  }
}
```

**Key Configuration Points:**

- **`topics`**: Reads from `taskflow-interactions` topic
- **`value.converter`**: Uses Avro converter to decode messages
- **`value.converter.schema.registry.url`**: Fetches schema from Schema Registry
- **`transforms.routeToTable`**: Maps topic name to Cassandra table name (`interactions`)
- **`pk.fields`**: Uses `id` field as primary key
- **`cassandra.write.mode`**: Uses `Insert` mode

### Step 6: Data Written to Cassandra

The connector writes the decoded event data to the Cassandra table:

**Cassandra Schema**

```sql
-- kafka/cassandra/init.cql
CREATE KEYSPACE IF NOT EXISTS taskflow
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

USE taskflow;

CREATE TABLE IF NOT EXISTS interactions (
  id TEXT PRIMARY KEY,
  action TEXT,
  who TEXT,
  what TEXT,
  time TEXT
) WITH default_time_to_live = 7776000;  -- 90 days TTL

-- Indexes for querying
CREATE INDEX IF NOT EXISTS idx_action ON interactions (action);
CREATE INDEX IF NOT EXISTS idx_who ON interactions (who);
```

**Data Mapping:**

- Kafka message key (event ID) → Cassandra primary key (`id`)
- Avro fields → Cassandra columns (`action`, `who`, `what`, `time`)

---

## Setup Process

The `setup-kafka.sh` script initializes the entire pipeline:

1. **Wait for services** (Kafka, Schema Registry, Kafka Connect, Cassandra)
2. **Create Kafka topic** (`taskflow-interactions`)
3. **Register Avro schema** in Schema Registry
4. **Initialize Cassandra** keyspace and tables
5. **Deploy Kafka Connect connector** to start the data pipeline

```bash
# Run setup script
./scripts/setup-kafka.sh
```

---

## Event Types Tracked

| Action     | Trigger           | Who                       | What       |
| ---------- | ----------------- | ------------------------- | ---------- |
| `view`     | Page navigation   | User email or "anonymous" | Page path  |
| `login`    | User login        | User email                | "login"    |
| `register` | User registration | User email                | "register" |
| `logout`   | User logout       | User email                | "logout"   |
| `create`   | Todo creation     | User email                | Todo title |
| `complete` | Todo toggle       | User email                | Todo title |
| `delete`   | Todo deletion     | User email                | Todo title |

---

## Code Locations

### Producer Code

- **Main Producer**: `src/lib/kafka/producer.ts`
- **Schema Definition**: `src/lib/kafka/schema.ts`
- **Type Definitions**: `src/lib/kafka/types.ts`
- **Public API**: `src/lib/kafka/index.ts`

### Tracking Actions

- **Page Views**: `src/features/tracking/actions.ts`
- **Auth Events**: `src/features/auth/actions.ts`
- **Todo Events**: `src/features/todos/actions.ts`

### Client Components

- **Page View Tracker**: `src/features/tracking/components/page-view-tracker.tsx`

### Infrastructure

- **Docker Compose**: `docker-compose.yml`
- **Setup Script**: `scripts/setup-kafka.sh`
- **Connector Config**: `kafka/connect/cassandra-sink.json`
- **Cassandra Schema**: `kafka/cassandra/init.cql`
- **Avro Schema**: `kafka/schemas/interaction-event.avsc`

---

## Benefits of This Architecture

1. **Decoupling**: Website doesn't directly write to Cassandra, reducing coupling
2. **Scalability**: Kafka can handle high throughput and buffer messages
3. **Reliability**: Messages are persisted in Kafka, preventing data loss
4. **Schema Evolution**: Avro schemas allow safe schema changes over time
5. **Real-time Processing**: Events flow in near real-time from website to database
6. **Fault Tolerance**: If Cassandra is down, events queue in Kafka until it recovers

---

## Querying Data

Once events are in Cassandra, you can query them:

```sql
-- View recent interactions
SELECT * FROM taskflow.interactions LIMIT 10;

-- Filter by action
SELECT * FROM taskflow.interactions WHERE action = 'create';

-- Filter by user
SELECT * FROM taskflow.interactions WHERE who = 'user@example.com';

-- Count events by action
SELECT action, COUNT(*) FROM taskflow.interactions GROUP BY action;
```

---

## Error Handling

- **Producer Errors**: Logged but don't break the application (non-blocking)
- **Connection Failures**: Producer retries with exponential backoff
- **Schema Mismatches**: Schema Registry validates schemas before encoding
- **Cassandra Failures**: Kafka Connect retries failed writes automatically

---

## Development Mode

You can disable Kafka tracking in development:

```bash
DISABLE_KAFKA=true npm run dev
```

This allows the app to run without Kafka infrastructure for local development.
