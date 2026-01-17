-- ============================================================================
-- Cassandra table for User Activity Aggregations from ksqlDB
-- ============================================================================
-- This table stores the real-time aggregated data from the 
-- USER_ACTIVITY_PER_MINUTE ksqlDB table with TUMBLING windows
--
-- NOTE: Column names use _VALUE suffix because ksqlDB uses AS_VALUE() 
-- to duplicate GROUP BY keys into the message value for sink connectors
-- ============================================================================

USE taskflow;

-- User activity aggregations table
-- Stores counts of user actions per category in 1-minute windows
CREATE TABLE IF NOT EXISTS user_activity_per_minute (
    -- Composite primary key: user + category + window start time
    -- Names match ksqlDB AS_VALUE() output (uppercase in Kafka, lowercase in Cassandra)
    user_email_value TEXT,
    event_category_value TEXT,
    window_start BIGINT,
    window_end BIGINT,
    -- Aggregation values
    event_count BIGINT,
    unique_actions BIGINT,
    action_list LIST<TEXT>,
    -- Primary key: partition by user_email and event_category, cluster by window_start
    PRIMARY KEY ((user_email_value, event_category_value), window_start)
) WITH CLUSTERING ORDER BY (window_start DESC)
  AND default_time_to_live = 604800;  -- 7 days TTL for aggregations

-- ============================================================================
-- Sample queries
-- ============================================================================

-- Get activity for a specific user
-- SELECT * FROM user_activity_per_minute WHERE user_email_value = 'user@example.com' AND event_category_value = 'AUTH';

-- Get recent activity windows for a user
-- SELECT * FROM user_activity_per_minute WHERE user_email_value = 'user@example.com' AND event_category_value = 'TASK' LIMIT 10;
