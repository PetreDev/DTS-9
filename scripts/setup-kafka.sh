#!/bin/bash

# Setup script for Kafka infrastructure
# This script creates the Kafka topic, registers the Avro schema,
# initializes the Cassandra keyspace/tables, and configures the sink connector

set -e

echo "=== Taskflow Kafka Setup ==="

# Wait for services to be ready
echo ""
echo "1. Waiting for services to be healthy..."

wait_for_http_service() {
  local name=$1
  local url=$2
  local max_attempts=30
  local attempt=0
  
  while [ $attempt -lt $max_attempts ]; do
    if curl -s "$url" > /dev/null 2>&1; then
      echo "   ✓ $name is ready"
      return 0
    fi
    attempt=$((attempt + 1))
    sleep 2
  done
  echo "   ✗ $name failed to start"
  exit 1
}

# Check Kafka using kafka-topics command inside the container
echo -n "   Checking Kafka..."
max_attempts=30
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

# Check if Cassandra is ready
echo -n "   Checking Cassandra..."
max_attempts=30
attempt=0
while [ $attempt -lt $max_attempts ]; do
  if docker exec task9-cassandra cqlsh -e "DESCRIBE KEYSPACES" > /dev/null 2>&1; then
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

# Create Kafka topics
echo ""
echo "2. Creating Kafka topics..."
# Create the main interactions topic
docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic taskflow-interactions \
  --partitions 3 \
  --replication-factor 1 \
  --config retention.ms=604800000 \
  --config cleanup.policy=delete
echo "   ✓ Topic 'taskflow-interactions' created"

# Pre-create the Confluent license/command topic with RF=1 for single-broker setup
docker exec task9-kafka kafka-topics --bootstrap-server localhost:9092 \
  --create --if-not-exists \
  --topic _confluent-command \
  --partitions 1 \
  --replication-factor 1
echo "   ✓ Pre-created Confluent internal topic with RF=1"

# Register Avro schema
echo ""
echo "3. Registering Avro schema..."
# Read schema and escape it for JSON (without jq dependency)
SCHEMA=$(cat kafka/schemas/interaction-event.avsc | tr -d '\n' | sed 's/"/\\"/g')
RESPONSE=$(curl -s -X POST -H "Content-Type: application/vnd.schemaregistry.v1+json" \
  --data "{\"schema\": \"$SCHEMA\"}" \
  http://localhost:8081/subjects/taskflow-interactions-value/versions)
echo "   Response: $RESPONSE"
echo "   ✓ Schema registered"

# Initialize Cassandra schema
echo ""
echo "4. Initializing Cassandra keyspace and tables..."
docker exec -i task9-cassandra cqlsh < kafka/cassandra/init.cql
echo "   ✓ Cassandra schema initialized"

# Wait a moment for Cassandra schema to propagate
sleep 2

# Deploy Kafka Connect sink connector
echo ""
echo "5. Deploying Cassandra sink connector..."
# Delete existing connector if it exists (makes script idempotent)
curl -s -X DELETE http://localhost:8083/connectors/cassandra-sink-interactions > /dev/null 2>&1 || true
sleep 2
CONNECTOR_RESPONSE=$(curl -s -X POST -H "Content-Type: application/json" \
  --data @kafka/connect/cassandra-sink.json \
  http://localhost:8083/connectors)
echo "   Response: $CONNECTOR_RESPONSE"
echo "   ✓ Connector deployed"

# Verify connector status
echo ""
echo "6. Verifying connector status..."
sleep 15
CONNECTOR_STATUS=$(curl -s http://localhost:8083/connectors/cassandra-sink-interactions/status)
echo "   Status: $CONNECTOR_STATUS"
# Check if both connector and task are running
if echo "$CONNECTOR_STATUS" | grep -q '"state":"RUNNING"' && echo "$CONNECTOR_STATUS" | grep -q '"tasks":\[{"id":0,"state":"RUNNING"'; then
  echo "   ✓ Connector and task are running"
elif echo "$CONNECTOR_STATUS" | grep -q '"state":"RUNNING"'; then
  echo "   ⚠ Connector is running but task may still be starting. Wait a few seconds and check again."
else
  echo "   ⚠ Connector may not be running. Check status above."
fi

echo ""
echo "=== Setup Complete ==="
echo ""
echo "Next steps:"
echo "  1. Start the Next.js app: npm run dev"
echo "  2. Interact with the app (login, create todos, etc.)"
echo "  3. Verify events in Cassandra:"
echo "     docker exec -it task9-cassandra cqlsh -e 'SELECT * FROM taskflow.interactions LIMIT 10'"
echo ""
