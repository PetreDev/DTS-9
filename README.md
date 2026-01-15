# Taskflow

A minimal, beautiful todo app built with Next.js 16 and modern best practices, with real-time event streaming to Cassandra via Kafka.

## Features

- 🎨 **Dark theme** with warm orange accents
- ⚡ **Lightning fast** with Next.js 16 Server Actions
- 🔐 **Secure** session-based authentication
- 📱 **Responsive** works on all devices
- ✨ **Smooth animations** and micro-interactions
- 📊 **Event streaming** - All interactions tracked via Kafka to Cassandra

## Tech Stack

- **Framework**: Next.js 16 (App Router)
- **Language**: TypeScript
- **Database**: PostgreSQL (Dockerized)
- **ORM**: Drizzle
- **Auth**: Better Auth
- **Forms**: React Hook Form + Zod
- **Styling**: Tailwind CSS
- **Event Streaming**: Kafka (KRaft), Schema Registry, Kafka Connect
- **Analytics Store**: Apache Cassandra

## Project Structure

```
src/
├── app/                    # Next.js App Router
│   ├── (auth)/             # Auth routes (login, register)
│   ├── (protected)/        # Protected routes (todos)
│   └── api/auth/           # Better Auth API
├── features/               # Feature modules
│   ├── auth/               # Auth feature
│   │   ├── components/     # Login/Register forms
│   │   └── schemas.ts      # Zod validation
│   ├── todos/              # Todo feature
│   │   ├── actions.ts      # Server Actions
│   │   ├── components/     # UI components
│   │   ├── repository.ts   # Data access layer
│   │   ├── schemas.ts      # Zod validation
│   │   └── service.ts      # Business logic
│   └── tracking/           # Event tracking feature
│       ├── actions.ts      # Track events to Kafka
│       └── components/     # Page view tracker
├── lib/
│   ├── auth/               # Better Auth config
│   ├── db/                 # Drizzle config & schema
│   └── kafka/              # Kafka producer & schema
└── proxy.ts                # Route protection
```

## Getting Started

### Prerequisites

- Node.js 20+
- Docker and Docker Compose
- npm or yarn

### 1. Start Infrastructure

Start PostgreSQL, Kafka, Schema Registry, Kafka Connect, and Cassandra:

```bash
docker-compose up -d
```

Wait for all services to be healthy (may take 1-2 minutes):

```bash
docker-compose ps
```

### 2. Install Dependencies

```bash
npm install
```

### 3. Set Up Environment

Create a `.env` file in the root directory. The app will work with default values for local development, but you can configure:

```env
# Database
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=app
DATABASE_URL=postgresql://postgres:postgres@localhost:5432/app

# Kafka
KAFKA_BROKERS=localhost:9092
SCHEMA_REGISTRY_URL=http://localhost:8081
DISABLE_KAFKA=false  # Set to "true" to disable event tracking
```

### 4. Set Up Kafka and Cassandra

Run the setup script to:

- Create the Kafka topic `taskflow-interactions`
- Register the Avro schema in Schema Registry
- Initialize Cassandra keyspace and tables
- Deploy the Cassandra Sink Connector

```bash
npm run kafka:setup
# or: ./scripts/setup-kafka.sh
```

### 5. Push Database Schema

```bash
npm run db:push
```

### 6. Run Development Server

```bash
npm run dev
```

Visit [http://localhost:3000](http://localhost:3000)

## Database Commands

```bash
npm run db:generate  # Generate migrations
npm run db:migrate   # Run migrations
npm run db:push      # Push schema directly (dev)
npm run db:studio    # Open Drizzle Studio
```

## Architecture

Clean layered architecture with type-safe error handling:

```
UI Components → Server Actions → Services → Repositories → Database
                     ↓
              Kafka Producer → Kafka → Kafka Connect → Cassandra
```

- **UI Components**: React components with React Hook Form
- **Server Actions**: Handle mutations with validation, return `ActionResult<T>`
- **Services**: Business logic layer
- **Repositories**: Data access layer (Drizzle queries)
- **Kafka Producer**: Async event tracking to Kafka with Avro serialization

## Event Streaming Setup

The app streams all user interactions to Cassandra via Kafka for analytics.

### Tracked Events

| Event Type      | Description                    |
| --------------- | ------------------------------ |
| `PAGE_VIEW`     | User views a page              |
| `USER_LOGIN`    | User logs in                   |
| `USER_REGISTER` | User registers                 |
| `USER_LOGOUT`   | User logs out                  |
| `TODO_CREATED`  | Todo is created                |
| `TODO_TOGGLED`  | Todo completion status changes |
| `TODO_DELETED`  | Todo is deleted                |

### Infrastructure

```
┌─────────────┐    ┌─────────────────┐    ┌──────────────┐    ┌───────────┐
│  Next.js    │───▸│  Kafka (KRaft)  │───▸│ Kafka Connect│───▸│ Cassandra │
│  Producer   │    │  + Schema Reg   │    │  + Avro Conv │    │           │
└─────────────┘    └─────────────────┘    └──────────────┘    └───────────┘
```

### Cassandra Schema

The Cassandra table uses a simplified schema for easy querying:

```sql
CREATE TABLE interactions (
  id TEXT PRIMARY KEY,      -- Unique event ID
  action TEXT,              -- Event type (PAGE_VIEW, TODO_CREATED, etc.)
  who TEXT,                 -- User ID
  what TEXT,                -- Event details (JSON string)
  time TEXT                 -- ISO timestamp
) WITH default_time_to_live = 7776000;  -- 90 days TTL
```

Indexes are created on `action` and `who` for efficient filtering.

### Querying Events in Cassandra

Connect to Cassandra:

```bash
docker exec -it task9-cassandra cqlsh
```

Example queries:

```sql
-- View recent events
SELECT id, action, who, what, "time"
FROM taskflow.interactions
LIMIT 20;

-- Get all login events
SELECT id, who, what, "time"
FROM taskflow.interactions
WHERE action = 'USER_LOGIN'
ALLOW FILTERING;

-- Get events for a specific user
SELECT id, action, what, "time"
FROM taskflow.interactions
WHERE who = 'USER_ID'
ALLOW FILTERING;

-- Count total events
SELECT COUNT(*) as total_events
FROM taskflow.interactions;
```

**Note**: The `time` column must be quoted in queries because it's a reserved keyword in CQL.

See `kafka/cassandra/queries.cql` for more example queries.

### Monitoring Events

You can monitor events in real-time by:

1. **Using cqlsh** - Connect and run queries periodically:

   ```bash
   docker exec -it task9-cassandra cqlsh
   SELECT id, action, who, what, "time" FROM taskflow.interactions LIMIT 5;
   ```

2. **Checking Kafka topic** - View messages in the Kafka topic:

   ```bash
   docker exec -it task9-kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic taskflow-interactions \
     --from-beginning
   ```

3. **Kafka Connect status** - Check connector status:
   ```bash
   curl http://localhost:8083/connectors/cassandra-sink-interactions/status
   ```

## Environment Variables

For production, configure:

```env
# Database
DATABASE_URL=postgresql://user:password@host:5432/dbname

# Kafka
KAFKA_BROKERS=kafka:29092
SCHEMA_REGISTRY_URL=http://schema-registry:8081
DISABLE_KAFKA=false  # Set to "true" to disable event tracking
```

## File Structure

```
kafka/
├── schemas/
│   └── interaction-event.avsc    # Avro schema for events
├── cassandra/
│   ├── init.cql                  # Cassandra keyspace and table definitions
│   └── queries.cql               # Example CQL queries
└── connect/
    └── cassandra-sink.json       # Kafka Connect connector configuration

scripts/
└── setup-kafka.sh                # One-time Kafka/Cassandra setup script

src/lib/kafka/
├── index.ts                      # Public exports
├── producer.ts                   # Kafka producer with Avro encoding
├── schema.ts                     # Schema definition
└── types.ts                      # TypeScript types for events
```

## Development

### Disabling Kafka

To disable event tracking during development, set:

```env
DISABLE_KAFKA=true
```

This will prevent the app from attempting to connect to Kafka.

### Troubleshooting

**Kafka connection issues:**

- Ensure all Docker services are running: `docker-compose ps`
- Check Kafka health: `docker exec -it task9-kafka kafka-topics --bootstrap-server localhost:9092 --list`
- Verify Schema Registry: `curl http://localhost:8081/subjects`

**Cassandra connection issues:**

- Wait for Cassandra to fully start (may take 60+ seconds)
- Check health: `docker exec -it task9-cassandra cqlsh -e "DESCRIBE KEYSPACES"`
- Verify connector: `curl http://localhost:8083/connectors`

**Events not appearing in Cassandra:**

- Check connector status: `curl http://localhost:8083/connectors/cassandra-sink-interactions/status`
- View connector logs: `docker logs task9-kafka-connect`
- Verify topic has messages: Use kafka-console-consumer to check the topic

## License

MIT
