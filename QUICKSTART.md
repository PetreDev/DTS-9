# Quick Start Guide

When you come back to this project fresh, you have two options:

## Option 1: Automated Start (Recommended)

Run the quick start script that does everything for you:

```bash
npm run quickstart
```

This will automatically:
1. Start all Docker services
2. Wait for services to be healthy
3. Install dependencies (if needed)
4. Setup Kafka and Cassandra
5. Push database schema
6. Start the development server

---

## Option 2: Manual Start

If you prefer to run steps manually, follow these steps:

## 1. Start Docker Services

Start all infrastructure (PostgreSQL, Kafka, Schema Registry, Kafka Connect, Cassandra, MinIO, ksqlDB):

```bash
docker-compose up -d
```

Wait 1-2 minutes for all services to be healthy, then verify:

```bash
docker-compose ps
```

All services should show as "healthy" or "running".

## 2. Install Dependencies (if needed)

If you don't have `node_modules` or after pulling updates:

```bash
npm install
```

## 3. Set Up Kafka and Cassandra (first time only)

This only needs to run once, but safe to run multiple times:

```bash
npm run kafka:setup
```

This script:
- Creates the Kafka topic `taskflow-interactions`
- Registers the Avro schema in Schema Registry
- Initializes Cassandra keyspace and tables
- **Deploys the Cassandra Sink Connector** (connects Kafka → Cassandra)

**Note**: While `docker-compose up` starts ksqlDB server, Kafka Connect, and Cassandra, **the connector instances are NOT created automatically**. You must run `npm run kafka:setup` to create the `cassandra-sink-interactions` connector that moves data from Kafka to Cassandra.

**ksqlDB Status**: ksqlDB server starts automatically and can manage connectors via Kafka Connect, but no ksqlDB streams/tables or connectors are created automatically. Use `scripts/ksqldb-demo.sh` to create ksqlDB objects if needed.

## 4. Push Database Schema

Initialize or update the PostgreSQL database schema:

```bash
npm run db:push
```

## 5. Start the Development Server

```bash
npm run dev
```

The app will be available at [http://localhost:3000](http://localhost:3000)

---

## Quick Checklist

- [ ] Docker services running (`docker-compose ps`)
- [ ] Dependencies installed (`npm install`)
- [ ] Kafka/Cassandra setup complete (`npm run kafka:setup`)
- [ ] Database schema pushed (`npm run db:push`)
- [ ] Dev server running (`npm run dev`)

---

## Troubleshooting

**If Docker services aren't starting:**
```bash
docker-compose down
docker-compose up -d
```

**If you need to reset everything:**
```bash
docker-compose down -v  # Removes volumes (WARNING: deletes all data)
docker-compose up -d
npm run kafka:setup
npm run db:push
```

**Check service status:**
```bash
# All services
docker-compose ps

# Specific service logs
docker logs task9-kafka
docker logs task9-postgres
docker logs task9-cassandra
```

---

## Optional: Test Event Streaming

Send a test event to verify Kafka is working:

```bash
npx tsx scripts/send-event.ts login user@test.com
```

Then check Cassandra:
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT * FROM taskflow.interactions LIMIT 5;"
```
