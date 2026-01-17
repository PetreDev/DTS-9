-- ============================================================================
-- ksqlDB Stream Processing for Taskflow Interactions
-- ============================================================================
-- This script creates streams and tables over the taskflow-interactions topic
-- Run these commands in the ksqlDB CLI:
--   docker exec -it task9-ksqldb-cli ksql http://ksqldb-server:8088
-- ============================================================================

-- Set offset to earliest to see all historical data
SET 'auto.offset.reset' = 'earliest';

-- ============================================================================
-- 1. CREATE A STREAM OVER THE TOPIC
-- ============================================================================
-- The topic uses Avro serialization with Schema Registry
-- Key is a String (event ID), Value is Avro-encoded InteractionEvent

CREATE STREAM IF NOT EXISTS interactions_stream (
    id STRING KEY,
    action STRING,
    who STRING,
    what STRING,
    time STRING
) WITH (
    KAFKA_TOPIC = 'taskflow-interactions',
    VALUE_FORMAT = 'AVRO',
    KEY_FORMAT = 'KAFKA'
);

-- ============================================================================
-- 2. DESCRIBE THE CREATED STREAM
-- ============================================================================

DESCRIBE interactions_stream;

DESCRIBE EXTENDED interactions_stream;

-- ============================================================================
-- 3. RUN A SIMPLE PULL QUERY OVER THE STREAM
-- ============================================================================
-- Note: Pull queries on streams require a WHERE clause with ROWKEY/key column
-- For streams without materialized views, we use push queries or LIMIT

SELECT * FROM interactions_stream EMIT CHANGES LIMIT 5;

-- ============================================================================
-- 4. RUN A SIMPLE PUSH QUERY OVER THE STREAM
-- ============================================================================
-- Push queries continuously emit results as new events arrive
-- Press Ctrl+C to stop the query

SELECT 
    id,
    action,
    who,
    what,
    time
FROM interactions_stream 
EMIT CHANGES 
LIMIT 10;

-- ============================================================================
-- 5. RUN A PUSH QUERY WITH FILTERING
-- ============================================================================
-- Filter for specific actions (e.g., only 'login' and 'logout' events)

SELECT 
    id,
    action,
    who,
    what,
    time
FROM interactions_stream 
WHERE action IN ('login', 'logout', 'register')
EMIT CHANGES 
LIMIT 10;

-- Filter for a specific user
SELECT 
    id,
    action,
    who,
    what,
    time
FROM interactions_stream 
WHERE who != 'anonymous'
EMIT CHANGES 
LIMIT 10;

-- ============================================================================
-- 6. CREATE A TRANSFORMED STREAM (CSAS - Create Stream As Select)
-- ============================================================================
-- This creates a new stream with:
-- - Renamed fields for clarity
-- - Standardized action names to uppercase
-- - Filtered to exclude 'view' actions (noisy)
-- - Added event categorization

CREATE STREAM IF NOT EXISTS interactions_enriched AS
SELECT
    id AS event_id,
    UCASE(action) AS event_type,
    CASE 
        WHEN action IN ('login', 'logout', 'register') THEN 'AUTH'
        WHEN action IN ('create', 'complete', 'delete') THEN 'TASK'
        WHEN action = 'view' THEN 'NAVIGATION'
        ELSE 'OTHER'
    END AS event_category,
    who AS user_email,
    CASE 
        WHEN who = 'anonymous' THEN 'ANONYMOUS'
        ELSE 'AUTHENTICATED'
    END AS user_type,
    what AS target,
    time AS event_time,
    ROWTIME AS kafka_timestamp
FROM interactions_stream
WHERE action != 'view'
EMIT CHANGES;

-- ============================================================================
-- 7. DESCRIBE THE TRANSFORMED STREAM
-- ============================================================================

DESCRIBE interactions_enriched;

DESCRIBE EXTENDED interactions_enriched;

-- ============================================================================
-- 8. RUN A QUERY OVER THE TRANSFORMED STREAM
-- ============================================================================
-- Push query showing the enriched data

SELECT 
    event_id,
    event_type,
    event_category,
    user_email,
    user_type,
    target,
    event_time
FROM interactions_enriched 
EMIT CHANGES 
LIMIT 10;

-- Filter by category
SELECT 
    event_id,
    event_type,
    user_email,
    target,
    event_time
FROM interactions_enriched 
WHERE event_category = 'AUTH'
EMIT CHANGES 
LIMIT 5;

-- ============================================================================
-- 9. CREATE A TABLE WITH TUMBLING WINDOW AGGREGATION (CTAS)
-- ============================================================================
-- Counts actions per user in 1-minute tumbling windows
-- This is useful for detecting user activity patterns
-- Note: Using KEY_FORMAT='JSON' for composite key support (user_email + event_category)
-- IMPORTANT: Use AS_VALUE() to duplicate key columns into the value for Cassandra sink

CREATE TABLE IF NOT EXISTS user_activity_per_minute
WITH (
    KEY_FORMAT = 'JSON',
    VALUE_FORMAT = 'AVRO'
) AS
SELECT
    user_email,
    event_category,
    AS_VALUE(user_email) AS user_email_value,
    AS_VALUE(event_category) AS event_category_value,
    WINDOWSTART AS window_start,
    WINDOWEND AS window_end,
    COUNT(*) AS event_count,
    COUNT_DISTINCT(event_type) AS unique_actions,
    COLLECT_LIST(event_type) AS action_list
FROM interactions_enriched
WINDOW TUMBLING (SIZE 1 MINUTE)
GROUP BY user_email, event_category
EMIT CHANGES;

-- ============================================================================
-- 10. DESCRIBE THE CREATED TABLE
-- ============================================================================

DESCRIBE user_activity_per_minute;

DESCRIBE EXTENDED user_activity_per_minute;

-- ============================================================================
-- 11. RUN A PULL QUERY OVER THE TABLE
-- ============================================================================
-- Pull queries on tables return the current state

-- Get all windowed aggregations (push query to see updates)
SELECT 
    user_email,
    event_category,
    TIMESTAMPTOSTRING(window_start, 'yyyy-MM-dd HH:mm:ss') AS window_start_time,
    TIMESTAMPTOSTRING(window_end, 'yyyy-MM-dd HH:mm:ss') AS window_end_time,
    event_count,
    unique_actions,
    action_list
FROM user_activity_per_minute
EMIT CHANGES
LIMIT 10;

-- ============================================================================
-- ADDITIONAL USEFUL QUERIES
-- ============================================================================

-- Show all active queries
SHOW QUERIES;

-- Show all streams
SHOW STREAMS;

-- Show all tables
SHOW TABLES;

-- Show all topics
SHOW TOPICS;

-- Show connectors
SHOW CONNECTORS;

-- ============================================================================
-- 12. CREATE CASSANDRA SINK CONNECTOR FOR AGGREGATION TABLE
-- ============================================================================
-- This connector writes the real-time aggregations from user_activity_per_minute
-- to Cassandra for persistent storage and querying
--
-- PREREQUISITE: Create the Cassandra table first:
--   docker exec -it task9-cassandra cqlsh -f /dev/stdin < kafka/cassandra/user_activity.cql
-- Or manually run:
--   USE taskflow;
--   CREATE TABLE IF NOT EXISTS user_activity_per_minute (
--       user_email_value TEXT,
--       event_category_value TEXT,
--       window_start BIGINT,
--       window_end BIGINT,
--       event_count BIGINT,
--       unique_actions BIGINT,
--       action_list LIST<TEXT>,
--       PRIMARY KEY ((user_email_value, event_category_value), window_start)
--   ) WITH CLUSTERING ORDER BY (window_start DESC);

CREATE SINK CONNECTOR IF NOT EXISTS cassandra_sink_user_activity WITH (
    'connector.class' = 'io.confluent.connect.cassandra.CassandraSinkConnector',
    'tasks.max' = '1',
    'topics' = 'USER_ACTIVITY_PER_MINUTE',
    'cassandra.contact.points' = 'cassandra',
    'cassandra.port' = '9042',
    'cassandra.keyspace' = 'taskflow',
    'cassandra.local.datacenter' = 'dc1',
    'cassandra.consistency.level' = 'LOCAL_ONE',
    'cassandra.write.mode' = 'Upsert',
    'pk.mode' = 'record_value',
    'pk.fields' = 'USER_EMAIL_VALUE,EVENT_CATEGORY_VALUE,WINDOW_START',
    'auto.create' = 'false',
    'auto.evolve' = 'false',
    'confluent.topic.bootstrap.servers' = 'kafka:29092',
    'key.converter' = 'org.apache.kafka.connect.json.JsonConverter',
    'key.converter.schemas.enable' = 'false',
    'value.converter' = 'io.confluent.connect.avro.AvroConverter',
    'value.converter.schema.registry.url' = 'http://schema-registry:8081'
);

-- ============================================================================
-- 13. VERIFY THE CONNECTOR
-- ============================================================================

-- Show all connectors
SHOW CONNECTORS;

-- Describe the connector
DESCRIBE CONNECTOR cassandra_sink_user_activity;

-- ============================================================================
-- CLEANUP (if needed - uncomment to use)
-- ============================================================================
-- DROP CONNECTOR IF EXISTS cassandra_sink_user_activity;
-- DROP TABLE IF EXISTS user_activity_per_minute DELETE TOPIC;
-- DROP STREAM IF EXISTS interactions_enriched DELETE TOPIC;
-- DROP STREAM IF EXISTS interactions_stream;
