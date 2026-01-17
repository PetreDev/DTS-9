#!/bin/bash
# ============================================================================
# ksqlDB Demo Script for Taskflow Interactions
# ============================================================================
# This script helps you run ksqlDB commands step by step
# ============================================================================

set -e

KSQLDB_SERVER="http://ksqldb-server:8088"
CLI_CONTAINER="task9-ksqldb-cli"

echo "=============================================="
echo "ksqlDB Demo for Taskflow Interactions"
echo "=============================================="
echo ""

# Check if ksqlDB server is running
echo "Checking ksqlDB server status..."
if ! docker exec $CLI_CONTAINER curl -s $KSQLDB_SERVER/info > /dev/null 2>&1; then
    echo "ERROR: ksqlDB server is not running."
    echo "Start it with: docker compose up -d ksqldb-server ksqldb-cli"
    exit 1
fi
echo "✓ ksqlDB server is running"
echo ""

# Function to run a ksqlDB command
run_ksql() {
    local cmd="$1"
    echo "Running: $cmd"
    echo "----------------------------------------"
    docker exec $CLI_CONTAINER ksql $KSQLDB_SERVER --execute "$cmd"
    echo ""
}

# Show menu
show_menu() {
echo "=============================================="
echo "Select an option:"
echo "=============================================="
echo "1.  Enter interactive ksqlDB CLI"
echo "2.  Show all topics"
echo "3.  Print records from taskflow-interactions topic"
echo "4.  Show connectors"
echo "5.  Show streams"
echo "6.  Show tables"
echo "7.  Show queries"
echo "8.  Create interactions_stream"
echo "9.  Describe interactions_stream"
echo "10. Query interactions_stream (limit 5)"
echo "11. Create transformed stream (interactions_enriched)"
echo "12. Describe interactions_enriched"
echo "13. Query interactions_enriched"
echo "14. Create aggregation table (user_activity_per_minute)"
echo "15. Describe user_activity_per_minute table"
echo "16. Query user_activity_per_minute table"
echo "17. Create Cassandra table for aggregations"
echo "18. Create Cassandra sink connector"
echo "19. Describe Cassandra sink connector"
echo "20. Query Cassandra for aggregations"
echo "21. Run full demo (create all objects + connector)"
echo "0.  Exit"
echo ""
}

# Interactive menu
while true; do
    show_menu
    read -p "Enter choice [0-21]: " choice
    echo ""
    
    case $choice in
        1)
            echo "Entering ksqlDB CLI. Type EXIT to return."
            docker exec -it $CLI_CONTAINER ksql $KSQLDB_SERVER
            ;;
        2)
            run_ksql "SHOW TOPICS;"
            ;;
        3)
            run_ksql "PRINT 'taskflow-interactions' FROM BEGINNING LIMIT 10;"
            ;;
        4)
            run_ksql "SHOW CONNECTORS;"
            ;;
        5)
            run_ksql "SHOW STREAMS;"
            ;;
        6)
            run_ksql "SHOW TABLES;"
            ;;
        7)
            run_ksql "SHOW QUERIES;"
            ;;
        8)
            run_ksql "CREATE STREAM IF NOT EXISTS interactions_stream (id STRING KEY, action STRING, who STRING, what STRING, time STRING) WITH (KAFKA_TOPIC = 'taskflow-interactions', VALUE_FORMAT = 'AVRO', KEY_FORMAT = 'KAFKA');"
            ;;
        9)
            run_ksql "DESCRIBE EXTENDED interactions_stream;"
            ;;
        10)
            run_ksql "SET 'auto.offset.reset' = 'earliest'; SELECT * FROM interactions_stream EMIT CHANGES LIMIT 5;"
            ;;
        11)
            run_ksql "CREATE STREAM IF NOT EXISTS interactions_enriched AS SELECT id AS event_id, UCASE(action) AS event_type, CASE WHEN action IN ('login', 'logout', 'register') THEN 'AUTH' WHEN action IN ('create', 'complete', 'delete') THEN 'TASK' WHEN action = 'view' THEN 'NAVIGATION' ELSE 'OTHER' END AS event_category, who AS user_email, CASE WHEN who = 'anonymous' THEN 'ANONYMOUS' ELSE 'AUTHENTICATED' END AS user_type, what AS target, time AS event_time, ROWTIME AS kafka_timestamp FROM interactions_stream WHERE action != 'view' EMIT CHANGES;"
            ;;
        12)
            run_ksql "DESCRIBE EXTENDED interactions_enriched;"
            ;;
        13)
            run_ksql "SET 'auto.offset.reset' = 'earliest'; SELECT event_id, event_type, event_category, user_email, target FROM interactions_enriched EMIT CHANGES LIMIT 5;"
            ;;
        14)
            run_ksql "CREATE TABLE IF NOT EXISTS user_activity_per_minute WITH (KEY_FORMAT = 'JSON', VALUE_FORMAT = 'AVRO') AS SELECT user_email, event_category, AS_VALUE(user_email) AS user_email_value, AS_VALUE(event_category) AS event_category_value, WINDOWSTART AS window_start, WINDOWEND AS window_end, COUNT(*) AS event_count, COUNT_DISTINCT(event_type) AS unique_actions, COLLECT_LIST(event_type) AS action_list FROM interactions_enriched WINDOW TUMBLING (SIZE 1 MINUTE) GROUP BY user_email, event_category EMIT CHANGES;"
            ;;
        15)
            run_ksql "DESCRIBE EXTENDED user_activity_per_minute;"
            ;;
        16)
            run_ksql "SET 'auto.offset.reset' = 'earliest'; SELECT user_email, event_category, TIMESTAMPTOSTRING(window_start, 'yyyy-MM-dd HH:mm:ss') AS window_start, event_count FROM user_activity_per_minute EMIT CHANGES LIMIT 5;"
            ;;
        17)
            echo "Creating Cassandra table for aggregations..."
            docker exec task9-cassandra cqlsh -e "USE taskflow; CREATE TABLE IF NOT EXISTS user_activity_per_minute (user_email_value TEXT, event_category_value TEXT, window_start BIGINT, window_end BIGINT, event_count BIGINT, unique_actions BIGINT, action_list LIST<TEXT>, PRIMARY KEY ((user_email_value, event_category_value), window_start)) WITH CLUSTERING ORDER BY (window_start DESC) AND default_time_to_live = 604800;"
            echo "✓ Cassandra table created"
            ;;
        18)
            run_ksql "CREATE SINK CONNECTOR IF NOT EXISTS cassandra_sink_user_activity WITH ('connector.class' = 'io.confluent.connect.cassandra.CassandraSinkConnector', 'tasks.max' = '1', 'topics' = 'USER_ACTIVITY_PER_MINUTE', 'cassandra.contact.points' = 'cassandra', 'cassandra.port' = '9042', 'cassandra.keyspace' = 'taskflow', 'cassandra.local.datacenter' = 'dc1', 'cassandra.consistency.level' = 'LOCAL_ONE', 'cassandra.write.mode' = 'Upsert', 'pk.mode' = 'record_value', 'pk.fields' = 'USER_EMAIL_VALUE,EVENT_CATEGORY_VALUE,WINDOW_START', 'auto.create' = 'false', 'auto.evolve' = 'false', 'confluent.topic.bootstrap.servers' = 'kafka:29092', 'key.converter' = 'org.apache.kafka.connect.json.JsonConverter', 'key.converter.schemas.enable' = 'false', 'value.converter' = 'io.confluent.connect.avro.AvroConverter', 'value.converter.schema.registry.url' = 'http://schema-registry:8081');"
            ;;
        19)
            run_ksql "DESCRIBE CONNECTOR cassandra_sink_user_activity;"
            ;;
        20)
            echo "Querying Cassandra for user_activity_per_minute..."
            docker exec task9-cassandra cqlsh -e "SELECT * FROM taskflow.user_activity_per_minute LIMIT 10;"
            ;;
        21)
            echo "Running full demo - creating all objects and connector..."
            echo ""
            
            echo "Step 1: Creating interactions_stream..."
            run_ksql "CREATE STREAM IF NOT EXISTS interactions_stream (id STRING KEY, action STRING, who STRING, what STRING, time STRING) WITH (KAFKA_TOPIC = 'taskflow-interactions', VALUE_FORMAT = 'AVRO', KEY_FORMAT = 'KAFKA');"
            
            echo "Step 2: Creating interactions_enriched stream (CSAS)..."
            run_ksql "CREATE STREAM IF NOT EXISTS interactions_enriched AS SELECT id AS event_id, UCASE(action) AS event_type, CASE WHEN action IN ('login', 'logout', 'register') THEN 'AUTH' WHEN action IN ('create', 'complete', 'delete') THEN 'TASK' WHEN action = 'view' THEN 'NAVIGATION' ELSE 'OTHER' END AS event_category, who AS user_email, CASE WHEN who = 'anonymous' THEN 'ANONYMOUS' ELSE 'AUTHENTICATED' END AS user_type, what AS target, time AS event_time, ROWTIME AS kafka_timestamp FROM interactions_stream WHERE action != 'view' EMIT CHANGES;"
            
            echo "Step 3: Creating user_activity_per_minute table (CTAS with TUMBLING window)..."
            run_ksql "CREATE TABLE IF NOT EXISTS user_activity_per_minute WITH (KEY_FORMAT = 'JSON', VALUE_FORMAT = 'AVRO') AS SELECT user_email, event_category, AS_VALUE(user_email) AS user_email_value, AS_VALUE(event_category) AS event_category_value, WINDOWSTART AS window_start, WINDOWEND AS window_end, COUNT(*) AS event_count, COUNT_DISTINCT(event_type) AS unique_actions, COLLECT_LIST(event_type) AS action_list FROM interactions_enriched WINDOW TUMBLING (SIZE 1 MINUTE) GROUP BY user_email, event_category EMIT CHANGES;"
            
            echo "Step 4: Creating Cassandra table..."
            docker exec task9-cassandra cqlsh -e "USE taskflow; CREATE TABLE IF NOT EXISTS user_activity_per_minute (user_email_value TEXT, event_category_value TEXT, window_start BIGINT, window_end BIGINT, event_count BIGINT, unique_actions BIGINT, action_list LIST<TEXT>, PRIMARY KEY ((user_email_value, event_category_value), window_start)) WITH CLUSTERING ORDER BY (window_start DESC) AND default_time_to_live = 604800;"
            
            echo "Step 5: Creating Cassandra sink connector..."
            run_ksql "CREATE SINK CONNECTOR IF NOT EXISTS cassandra_sink_user_activity WITH ('connector.class' = 'io.confluent.connect.cassandra.CassandraSinkConnector', 'tasks.max' = '1', 'topics' = 'USER_ACTIVITY_PER_MINUTE', 'cassandra.contact.points' = 'cassandra', 'cassandra.port' = '9042', 'cassandra.keyspace' = 'taskflow', 'cassandra.local.datacenter' = 'dc1', 'cassandra.consistency.level' = 'LOCAL_ONE', 'cassandra.write.mode' = 'Upsert', 'pk.mode' = 'record_value', 'pk.fields' = 'USER_EMAIL_VALUE,EVENT_CATEGORY_VALUE,WINDOW_START', 'auto.create' = 'false', 'auto.evolve' = 'false', 'confluent.topic.bootstrap.servers' = 'kafka:29092', 'key.converter' = 'org.apache.kafka.connect.json.JsonConverter', 'key.converter.schemas.enable' = 'false', 'value.converter' = 'io.confluent.connect.avro.AvroConverter', 'value.converter.schema.registry.url' = 'http://schema-registry:8081');"
            
            echo "=============================================="
            echo "Demo complete! All objects and connector created."
            echo "=============================================="
            run_ksql "SHOW STREAMS;"
            run_ksql "SHOW TABLES;"
            run_ksql "SHOW CONNECTORS;"
            run_ksql "SHOW QUERIES;"
            ;;
        0)
            echo "Goodbye!"
            exit 0
            ;;
        *)
            echo "Invalid option. Please try again."
            ;;
    esac
    
    read -p "Press Enter to continue..."
    echo ""
done
