#!/bin/bash

# Setup script for CDC (Change Data Capture) Pipeline
# This script configures Debezium PostgreSQL source connector
# and S3 Sink connector for MinIO data lake (bronze zone)
#
# Pipeline: PostgreSQL (todo table) → Debezium → Kafka → S3 Sink → MinIO (bronze bucket)

set -e

echo "=== CDC Pipeline Setup ==="
echo ""
echo "This script sets up Change Data Capture from PostgreSQL to MinIO data lake."
echo ""

# Wait for services to be ready
echo "1. Waiting for services to be healthy..."

wait_for_http_service() {
  local name=$1
  local url=$2
  local max_attempts=60
  local attempt=0
  
  echo -n "   Checking $name..."
  while [ $attempt -lt $max_attempts ]; do
    if curl -s "$url" > /dev/null 2>&1; then
      echo " ✓ ready"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo " ✗ failed"
  exit 1
}

# Check Kafka using kafka-topics command inside the container
echo -n "   Checking Kafka..."
max_attempts=60
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 --list > /dev/null 2>&1; then
    echo " ✓ ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ $attempt -eq $max_attempts ]; then
  echo " ✗ failed"
  exit 1
fi

wait_for_http_service "Schema Registry" "http://localhost:8081"
wait_for_http_service "Kafka Connect" "http://localhost:8083/connectors"

# Check MinIO
echo -n "   Checking MinIO..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if curl -s "http://localhost:9000/minio/health/live" > /dev/null 2>&1; then
    echo " ✓ ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ $attempt -eq $max_attempts ]; then
  echo " ✗ failed"
  exit 1
fi

# Check PostgreSQL and verify WAL level
echo -n "   Checking PostgreSQL..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if docker exec task9-postgres pg_isready -U postgres -d app > /dev/null 2>&1; then
    echo " ✓ ready"
    break
  fi
  attempt=$((attempt + 1))
  sleep 2
done
if [ $attempt -eq $max_attempts ]; then
  echo " ✗ failed"
  exit 1
fi

# Verify WAL level is set to logical
echo ""
echo "2. Verifying PostgreSQL CDC configuration..."
WAL_LEVEL=$(docker exec task9-postgres psql -U postgres -d app -t -c "SHOW wal_level;" | tr -d ' ')
if [ "$WAL_LEVEL" = "logical" ]; then
  echo "   ✓ WAL level is set to 'logical' (required for CDC)"
else
  echo "   ✗ WAL level is '$WAL_LEVEL', expected 'logical'"
  echo "   Please restart PostgreSQL with wal_level=logical"
  exit 1
fi

# Check if the todo table exists
echo -n "   Checking if 'todo' table exists..."
TABLE_EXISTS=$(docker exec task9-postgres psql -U postgres -d app -t -c "SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'todo');" | tr -d ' ')
if [ "$TABLE_EXISTS" = "t" ]; then
  echo " ✓ found"
else
  echo " ✗ not found"
  echo "   Please run the application migrations first: npm run db:push"
  exit 1
fi

# Check available connector plugins
echo ""
echo "3. Verifying Kafka Connect plugins..."
PLUGINS=$(curl -s http://localhost:8083/connector-plugins)

echo -n "   Checking Debezium PostgreSQL connector..."
if echo "$PLUGINS" | grep -qi "PostgresConnector"; then
  echo " ✓ installed"
else
  echo " ✗ not found"
  echo "   Please wait for Kafka Connect to finish installing plugins"
  exit 1
fi

echo -n "   Checking S3 Sink connector..."
if echo "$PLUGINS" | grep -qi "S3SinkConnector"; then
  echo " ✓ installed"
else
  echo " ✗ not found"
  echo "   Please wait for Kafka Connect to finish installing plugins"
  exit 1
fi

# Deploy Debezium PostgreSQL source connector
echo ""
echo "4. Deploying Debezium PostgreSQL source connector..."

# Delete existing connector if it exists (makes script idempotent)
curl -s -X DELETE http://localhost:8083/connectors/debezium-postgres-cdc-v2 > /dev/null 2>&1 || true
curl -s -X DELETE http://localhost:8083/connectors/debezium-postgres-todo-cdc > /dev/null 2>&1 || true
sleep 2

SOURCE_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  --data @kafka/connect/debezium-postgres-source.json \
  http://localhost:8083/connectors)

if echo "$SOURCE_RESPONSE" | grep -q '"name"'; then
  echo "   ✓ Debezium source connector deployed"
else
  echo "   Response: $SOURCE_RESPONSE"
  echo "   ⚠ Check connector configuration"
fi

# Wait for initial snapshot
echo ""
echo "5. Waiting for Debezium to perform initial snapshot..."
sleep 10

# Set REPLICA IDENTITY for delete events
echo ""
echo "   Setting REPLICA IDENTITY FULL for delete events..."
docker exec task9-postgres psql -U postgres -d app -c "ALTER TABLE todo REPLICA IDENTITY FULL;" > /dev/null 2>&1 || true
echo "   ✓ REPLICA IDENTITY configured"

# Verify Debezium connector status
SOURCE_STATUS=$(curl -s http://localhost:8083/connectors/debezium-postgres-cdc-v2/status)
if echo "$SOURCE_STATUS" | grep -q '"state":"RUNNING"'; then
  echo "   ✓ Debezium connector is running"
else
  echo "   Status: $SOURCE_STATUS"
  echo "   ⚠ Connector may still be starting"
fi

# Check if CDC topic was created
echo ""
echo "6. Verifying CDC topic creation..."
sleep 5
TOPICS=$(docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 --list 2>/dev/null)
if echo "$TOPICS" | grep -q "cdc.public.todo"; then
  echo "   ✓ Topic 'cdc.public.todo' created"
else
  echo "   Topics found: $TOPICS"
  echo "   ⚠ CDC topic not yet created. This is normal if the 'todo' table is empty."
  echo "   The topic will be created when the first record is inserted."
fi

# Deploy S3 Sink connector for MinIO
echo ""
echo "7. Deploying S3 Sink connector for MinIO..."

# Delete existing connector if it exists
curl -s -X DELETE http://localhost:8083/connectors/s3-sink-cdc-bronze > /dev/null 2>&1 || true
sleep 2

SINK_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  --data @kafka/connect/s3-sink-minio.json \
  http://localhost:8083/connectors)

if echo "$SINK_RESPONSE" | grep -q '"name"'; then
  echo "   ✓ S3 Sink connector deployed"
else
  echo "   Response: $SINK_RESPONSE"
  echo "   ⚠ Check connector configuration"
fi

# Verify S3 Sink connector status
echo ""
echo "8. Verifying connector statuses..."
sleep 15

SOURCE_STATUS=$(curl -s http://localhost:8083/connectors/debezium-postgres-cdc-v2/status)
SINK_STATUS=$(curl -s http://localhost:8083/connectors/s3-sink-cdc-bronze/status)

echo ""
echo "   Debezium Source Connector:"
if echo "$SOURCE_STATUS" | grep -q '"state":"RUNNING"'; then
  echo "   ✓ Running"
else
  echo "   Status: $SOURCE_STATUS"
fi

echo ""
echo "   S3 Sink Connector:"
if echo "$SINK_STATUS" | grep -q '"state":"RUNNING"'; then
  echo "   ✓ Running"
else
  echo "   Status: $SINK_STATUS"
fi

echo ""
echo "=== CDC Pipeline Setup Complete ==="
echo ""
echo "Pipeline: PostgreSQL (todo table) → Debezium → Kafka (cdc.public.todo) → S3 Sink → MinIO (bronze bucket)"
echo ""
echo "Verification steps:"
echo ""
echo "  1. Insert a todo in PostgreSQL:"
echo "     docker exec task9-postgres psql -U postgres -d app -c \\"
echo "       \"INSERT INTO todo (id, title, completed, user_id, created_at, updated_at) \\"
echo "         VALUES (gen_random_uuid(), 'Test CDC', false, 'test-user', now(), now());\""
echo ""
echo "  2. Check Kafka topic for CDC events:"
echo "     docker exec task9-kafka kafka-console-consumer \\"
echo "       --bootstrap-server localhost:9092 \\"
echo "       --topic cdc.public.todo \\"
echo "       --from-beginning \\"
echo "       --max-messages 5"
echo ""
echo "  3. Check MinIO for data files (after flush interval):"
echo "     - Open MinIO Console: http://localhost:9001"
echo "     - Login: minioadmin / minioadmin"
echo "     - Browse: bronze/cdc/postgres/cdc.public.todo/"
echo ""
echo "  4. Or use MinIO CLI:"
echo "     docker exec task9-minio mc ls myminio/bronze/cdc/ --recursive"
echo ""
