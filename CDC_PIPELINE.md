# CDC Pipeline: PostgreSQL → Kafka → MinIO Data Lake

This document explains how Change Data Capture (CDC) is implemented to stream database changes from PostgreSQL into a MinIO data lake (bronze zone).

## Overview

The CDC pipeline captures all INSERT, UPDATE, and DELETE operations on the PostgreSQL `todo` table and streams them to MinIO for analytics and data lake storage.

```
PostgreSQL (todo table) → Debezium → Kafka → S3 Sink → MinIO (bronze bucket)
```

## Architecture Components

### 1. **PostgreSQL** (Source Database)

- Configured with `wal_level=logical` for CDC support
- Uses the `pgoutput` logical decoding plugin (built into PostgreSQL 10+)
- Replication slots created automatically by Debezium

### 2. **Debezium PostgreSQL Connector 3.4.0.Final** (CDC Source)

- Captures row-level changes from the PostgreSQL WAL
- Performs initial snapshot on first run
- Publishes changes to Kafka topic `cdc.public.todo`
- Manually installed from: https://debezium.io/releases/3.4/
- Location: `kafka/plugins/debezium-connector-postgres/`

### 3. **Kafka** (Message Queue)

- Stores CDC events with full change history
- Topic: `cdc.public.todo`
- Enables decoupling between source and sink

### 4. **S3 Sink Connector 12.0.0** (Data Lake Writer)

- Reads from Kafka CDC topic
- Writes JSON files to MinIO
- Partitions by time (year/month/day/hour)
- Manually installed from: https://www.confluent.io/hub/confluentinc/kafka-connect-s3
- Location: `kafka/plugins/s3-sink-connector/`

### 5. **MinIO** (S3-Compatible Data Lake)

- Bronze zone storage for raw CDC events
- S3-compatible API
- Web console for browsing data

---

## Configuration Details

### PostgreSQL CDC Settings

The PostgreSQL container is configured with the following parameters for CDC:

```yaml
# docker-compose.yml
command:
  - "postgres"
  - "-c"
  - "wal_level=logical"          # Required for logical replication
  - "-c"
  - "max_replication_slots=4"    # Slots for Debezium connections
  - "-c"
  - "max_wal_senders=4"          # WAL sender processes
```

### Debezium PostgreSQL Source Connector

Configuration file: `kafka/connect/debezium-postgres-source.json`

Key settings:

| Setting | Value | Description |
|---------|-------|-------------|
| `connector.class` | `io.debezium.connector.postgresql.PostgresConnector` | Debezium PostgreSQL connector |
| `topic.prefix` | `cdc` | Prefix for Kafka topics |
| `table.include.list` | `public.todo` | Table to capture changes from |
| `plugin.name` | `pgoutput` | PostgreSQL logical decoding plugin |
| `snapshot.mode` | `initial` | Perform full snapshot on first run |
| `tombstones.on.delete` | `true` | Generate tombstone records for deletes |

The connector uses the `ExtractNewRecordState` transform to flatten the Debezium envelope into a simpler format with added metadata fields:
- `__op`: Operation type (c=create, u=update, d=delete)
- `__table`: Source table name
- `__source_ts_ms`: Source timestamp in milliseconds

### S3 Sink Connector for MinIO

Configuration file: `kafka/connect/s3-sink-minio.json`

Key settings:

| Setting | Value | Description |
|---------|-------|-------------|
| `s3.bucket.name` | `bronze` | Target bucket (bronze zone) |
| `store.url` | `http://minio:9000` | MinIO S3 endpoint |
| `format.class` | `JsonFormat` | Output format |
| `partitioner.class` | `TimeBasedPartitioner` | Time-based partitioning |
| `path.format` | `'year'=YYYY/'month'=MM/'day'=dd/'hour'=HH` | Directory structure |
| `flush.size` | `100` | Records per file |
| `rotate.interval.ms` | `60000` | Rotate files every 60 seconds |

### MinIO Configuration

| Setting | Value |
|---------|-------|
| S3 API Port | 9000 |
| Console Port | 9001 |
| Access Key | `minioadmin` |
| Secret Key | `minioadmin` |
| Bucket | `bronze` |

---

## CDC Event Format

### INSERT Event

When a new todo is created:

```json
{
  "schema": {...},
  "payload": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Buy groceries",
    "completed": false,
    "user_id": "user123",
    "created_at": 1705401600000,
    "updated_at": 1705401600000,
    "__op": "c",
    "__table": "todo",
    "__source_ts_ms": 1705401600123
  }
}
```

### UPDATE Event

When a todo is modified:

```json
{
  "schema": {...},
  "payload": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Buy groceries",
    "completed": true,
    "user_id": "user123",
    "created_at": 1705401600000,
    "updated_at": 1705405200000,
    "__op": "u",
    "__table": "todo",
    "__source_ts_ms": 1705405200456
  }
}
```

### DELETE Event

When a todo is deleted:

```json
{
  "schema": {...},
  "payload": {
    "id": "550e8400-e29b-41d4-a716-446655440000",
    "title": "Buy groceries",
    "completed": true,
    "user_id": "user123",
    "created_at": 1705401600000,
    "updated_at": 1705405200000,
    "__deleted": "true",
    "__op": "d",
    "__table": "todo",
    "__source_ts_ms": 1705408800789
  }
}
```

---

## Data Lake Structure

Data is stored in MinIO with the following structure:

```
bronze/
└── cdc/
    └── postgres/
        └── cdc.public.todo/
            └── year=2024/
                └── month=01/
                    └── day=16/
                        └── hour=14/
                            ├── cdc.public.todo+0+0000000000.json
                            ├── cdc.public.todo+0+0000000100.json
                            └── ...
```

Each file contains up to 100 CDC records (configurable via `flush.size`).

---

## Setup Instructions

### 1. Download Kafka Connect Plugins

The CDC pipeline requires manually downloaded plugins (not included in git):

```bash
# Create plugins directory
mkdir -p kafka/plugins

# Download Debezium PostgreSQL Connector 3.4.0.Final
cd kafka/plugins
curl -L -o debezium-postgres.tar.gz \
  https://repo1.maven.org/maven2/io/debezium/debezium-connector-postgres/3.4.0.Final/debezium-connector-postgres-3.4.0.Final-plugin.tar.gz
tar -xzf debezium-postgres.tar.gz
rm debezium-postgres.tar.gz
cd ../..

# Download S3 Sink Connector 12.0.0
# From: https://www.confluent.io/hub/confluentinc/kafka-connect-s3
# Download the "Self-Hosted" ZIP and extract to kafka/plugins/s3-sink-connector/
```

After extraction, you should have:
```
kafka/plugins/
├── debezium-connector-postgres/
│   └── *.jar files
└── s3-sink-connector/
    └── *.jar files
```

### 2. Start All Services

```bash
docker compose up -d
```

### 3. Wait for Services to be Healthy

```bash
docker compose ps
```

Ensure all services show "healthy" status.

### 4. Run Database Migrations

```bash
npm run db:push
```

This creates the `todo` table if it doesn't exist.

### 5. Run CDC Setup Script

```bash
./scripts/setup-cdc.sh
```

This script:
1. Verifies PostgreSQL CDC configuration
2. Checks that the `todo` table exists
3. Deploys the Debezium source connector
4. Deploys the S3 sink connector
5. Verifies both connectors are running

---

## Verification

### 1. Insert Test Data

```bash
docker exec task9-postgres psql -U postgres -d app -c \
  "INSERT INTO todo (id, title, completed, user_id, created_at, updated_at) \
    VALUES (gen_random_uuid(), 'Test CDC', false, 'test-user', now(), now());"
```

### 2. Check Kafka Topic

```bash
docker exec task9-kafka kafka-console-consumer \
  --bootstrap-server localhost:9092 \
  --topic cdc.public.todo \
  --from-beginning \
  --max-messages 5
```

### 3. Check MinIO Console

1. Open http://localhost:9001
2. Login with `minioadmin` / `minioadmin`
3. Navigate to: `bronze/cdc/postgres/cdc.public.todo/`

### 4. Test UPDATE Operation

```bash
docker exec task9-postgres psql -U postgres -d app -c \
  "UPDATE todo SET completed = true WHERE title = 'Test CDC';"
```

### 5. Test DELETE Operation

```bash
docker exec task9-postgres psql -U postgres -d app -c \
  "DELETE FROM todo WHERE title = 'Test CDC';"
```

---

## Connector Management

### List All Connectors

```bash
curl http://localhost:8083/connectors
```

### Check Connector Status

```bash
# Debezium source
curl http://localhost:8083/connectors/debezium-postgres-todo-cdc/status | jq

# S3 sink
curl http://localhost:8083/connectors/s3-sink-cdc-bronze/status | jq
```

### Restart a Connector

```bash
curl -X POST http://localhost:8083/connectors/debezium-postgres-todo-cdc/restart
```

### Delete a Connector

```bash
curl -X DELETE http://localhost:8083/connectors/debezium-postgres-todo-cdc
```

---

## Troubleshooting

### Connector Not Starting

1. Check Kafka Connect logs:
   ```bash
   docker logs task9-kafka-connect
   ```

2. Verify connector plugins are installed:
   ```bash
   curl http://localhost:8083/connector-plugins | jq
   ```

### No CDC Events in Kafka

1. Verify WAL level:
   ```bash
   docker exec task9-postgres psql -U postgres -d app -c "SHOW wal_level;"
   ```

2. Check replication slots:
   ```bash
   docker exec task9-postgres psql -U postgres -d app -c \
     "SELECT * FROM pg_replication_slots;"
   ```

3. Insert data and check the topic:
   ```bash
   docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 --list
   ```

### No Data in MinIO

1. Wait for flush interval (60 seconds by default)
2. Check S3 sink connector status
3. Verify MinIO is accessible:
   ```bash
   curl http://localhost:9000/minio/health/live
   ```

---

## Code Locations

| Component | Location |
|-----------|----------|
| Docker Compose | `docker-compose.yml` |
| Debezium Config | `kafka/connect/debezium-postgres-source.json` |
| S3 Sink Config | `kafka/connect/s3-sink-minio.json` |
| Setup Script | `scripts/setup-cdc.sh` |
| Database Schema | `src/lib/db/schema.ts` |

---

## Benefits of This Architecture

1. **Real-time Data Lake**: Changes are streamed to MinIO within seconds
2. **Complete Audit Trail**: All INSERT/UPDATE/DELETE operations are captured
3. **Schema Evolution**: Debezium tracks schema changes automatically
4. **Fault Tolerance**: Kafka buffers events if MinIO is temporarily unavailable
5. **Time-Based Partitioning**: Efficient querying of historical data
6. **S3 Compatibility**: Data lake can be queried with tools like Spark, Presto, or Athena
