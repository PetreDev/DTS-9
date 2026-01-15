-- Example CQL Queries for Verifying Streaming Events
-- Run these queries to see new rows appearing as interactions occur

-- =====================================================
-- BASIC QUERIES
-- =====================================================

-- View the most recent interactions (all types)
SELECT id, action, who, what, "time"
FROM taskflow.interactions
LIMIT 20;

-- Count total events in the system
SELECT COUNT(*) as total_events
FROM taskflow.interactions;

-- =====================================================
-- FILTERED QUERIES (using secondary indexes)
-- =====================================================

-- Get events for a specific user
SELECT id, action, what, "time"
FROM taskflow.interactions
WHERE who = 'USER_ID'
ALLOW FILTERING;

-- Get all login events
SELECT id, who, what, "time"
FROM taskflow.interactions
WHERE action = 'USER_LOGIN'
ALLOW FILTERING;

-- Get all todo creation events
SELECT id, who, what, "time"
FROM taskflow.interactions
WHERE action = 'TODO_CREATED'
ALLOW FILTERING;

-- Get all page views
SELECT id, who, what, "time"
FROM taskflow.interactions
WHERE action = 'PAGE_VIEW'
ALLOW FILTERING;

-- =====================================================
-- REAL-TIME MONITORING
-- =====================================================

-- Watch for new events (run periodically)
-- Shows latest 5 events with full details
SELECT id, action, who, what, "time"
FROM taskflow.interactions
LIMIT 5;

-- Check event flow health - should see increasing counts
-- Run this multiple times while using the app
SELECT COUNT(*) as event_count FROM taskflow.interactions;

-- =====================================================
-- DEBUGGING QUERIES
-- =====================================================

-- Check if any events exist
SELECT * FROM taskflow.interactions LIMIT 1;

-- Check table structure
DESCRIBE TABLE taskflow.interactions;

-- Check keyspace
DESCRIBE KEYSPACE taskflow;