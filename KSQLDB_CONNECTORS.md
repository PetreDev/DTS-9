# ksqlDB Connectors Guide

## How to Check ksqlDB Connectors

### Method 1: Using ksqlDB CLI (Interactive)

Connect to ksqlDB CLI and run commands:

```bash
# Enter ksqlDB CLI
docker exec -it task9-ksqldb-cli ksql http://ksqldb-server:8088

# Once inside ksqlDB, run:
SHOW CONNECTORS;

# Get detailed info about a specific connector
DESCRIBE CONNECTOR <connector_name>;

# Check connector status
SHOW CONNECTORS EXTENDED;
```

### Method 2: Using ksqlDB CLI (One-liner)

Run commands directly from bash:

```bash
# Show all connectors
docker exec task9-ksqldb-cli ksql http://ksqldb-server:8088 --execute "SHOW CONNECTORS;"

# Describe a specific connector
docker exec task9-ksqldb-cli ksql http://ksqldb-server:8088 --execute "DESCRIBE CONNECTOR cassandra_sink_user_activity;"

# Show connectors with extended info
docker exec task9-ksqldb-cli ksql http://ksqldb-server:8088 --execute "SHOW CONNECTORS EXTENDED;"
```

### Method 3: Using the Demo Script

Use the interactive demo script:

```bash
./scripts/ksqldb-demo.sh
# Then select option 4: "Show connectors"
```

### Method 4: Direct Kafka Connect API (All Connectors)

Since ksqlDB connectors are managed via Kafka Connect, you can also check via Kafka Connect REST API:

```bash
# List all connectors (includes ksqlDB-managed ones)
curl http://localhost:8083/connectors | jq

# Check status of a specific connector
curl http://localhost:8083/connectors/cassandra_sink_user_activity/status | jq

# Get connector config
curl http://localhost:8083/connectors/cassandra_sink_user_activity/config | jq
```

**Note**: Connectors created via ksqlDB will appear in both ksqlDB (`SHOW CONNECTORS`) and Kafka Connect API.

---

## Persistence: Will Connectors Survive `docker-compose down`?

### ✅ `docker-compose down` (WITHOUT `-v` flag)

**Connectors WILL persist** because:

1. **Connector configurations** are stored in Kafka topics:
   - `_connect-configs` - Connector configurations
   - `_connect-offsets` - Connector offsets
   - `_connect-status` - Connector status

2. **Kafka data is in a volume** (`kafka_data`) that persists across container restarts

3. **What happens**:
   - Containers stop
   - Volumes remain intact
   - Kafka topics with connector configs are preserved
   - When you `docker-compose up` again, Kafka Connect reads the configs from topics and recreates the connectors

### ❌ `docker-compose down -v` (WITH `-v` flag)

**Connectors WILL BE LOST** because:

- The `-v` flag removes all volumes
- `kafka_data` volume is deleted
- All Kafka topics (including `_connect-configs`) are lost
- You'll need to run `npm run kafka:setup` again to recreate connectors

---

## Persistence Details

### Kafka Connect Connector Storage

Kafka Connect stores connector state in these Kafka topics (defined in `docker-compose.yml`):

```yaml
CONNECT_CONFIG_STORAGE_TOPIC: _connect-configs   # Connector configs
CONNECT_OFFSET_STORAGE_TOPIC: _connect-offsets   # Processing offsets
CONNECT_STATUS_STORAGE_TOPIC: _connect-status    # Status/health
```

These topics are stored in the `kafka_data` volume, which persists unless you use `docker-compose down -v`.

### ksqlDB Streams and Tables

**ksqlDB streams and tables also persist** in the same way:

- They're stored as Kafka topics (e.g., `INTERACTIONS_ENRICHED`, `USER_ACTIVITY_PER_MINUTE`)
- These topics are in the `kafka_data` volume
- `docker-compose down` → streams/tables persist ✅
- `docker-compose down -v` → streams/tables are lost ❌

**However**: ksqlDB metadata about streams/tables might not persist if ksqlDB's internal topics are lost. It's generally safe to recreate streams/tables with `IF NOT EXISTS` clauses.

---

## Best Practices

### 1. Always use `IF NOT EXISTS` in ksqlDB

When creating connectors, streams, or tables, use `IF NOT EXISTS`:

```sql
CREATE SINK CONNECTOR IF NOT EXISTS cassandra_sink_user_activity WITH (...);
CREATE STREAM IF NOT EXISTS interactions_stream (...);
CREATE TABLE IF NOT EXISTS user_activity_per_minute (...);
```

This makes your scripts idempotent and safe to run multiple times.

### 2. Document Your Connectors

Keep track of what connectors you've created. You can list them:

```bash
# Save connector list
docker exec task9-ksqldb-cli ksql http://ksqldb-server:8088 --execute "SHOW CONNECTORS;" > connectors.txt
```

### 3. Backup Before `docker-compose down -v`

If you need to remove volumes, export connector configs first:

```bash
# Export all connector configs
curl http://localhost:8083/connectors | jq -r '.[]' | while read connector; do
  curl http://localhost:8083/connectors/$connector/config > connector_${connector}_config.json
done
```

### 4. Verify Connectors After Restart

After `docker-compose up`, verify connectors are running:

```bash
# Wait for services to be healthy
docker-compose ps

# Check connector status
curl http://localhost:8083/connectors/cassandra-sink-interactions/status | jq

# Or via ksqlDB
docker exec task9-ksqldb-cli ksql http://ksqldb-server:8088 --execute "SHOW CONNECTORS;"
```

---

## Quick Reference

| Command | Description |
|---------|-------------|
| `SHOW CONNECTORS;` | List all connectors in ksqlDB |
| `DESCRIBE CONNECTOR <name>;` | Get details about a connector |
| `DROP CONNECTOR <name>;` | Delete a connector |
| `curl http://localhost:8083/connectors` | List all connectors (Kafka Connect API) |
| `curl http://localhost:8083/connectors/<name>/status` | Check connector status |

---

## Troubleshooting

**Connectors not showing after restart?**

1. Check if Kafka topics exist:
   ```bash
   docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 --list | grep _connect
   ```

2. Check Kafka Connect logs:
   ```bash
   docker logs task9-kafka-connect
   ```

3. Verify connector config topics have data:
   ```bash
   docker exec task9-kafka kafka-console-consumer \
     --bootstrap-server localhost:9092 \
     --topic _connect-configs \
     --from-beginning
   ```

**Connector status shows `FAILED`?**

Check the connector status for error messages:
```bash
curl http://localhost:8083/connectors/<connector-name>/status | jq '.tasks[0].trace'
```
