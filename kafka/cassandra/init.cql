-- Simple Cassandra schema for Taskflow events

-- Create keyspace
CREATE KEYSPACE IF NOT EXISTS taskflow
WITH replication = {
  'class': 'SimpleStrategy',
  'replication_factor': 1
};

USE taskflow;

-- Simple interactions table with readable columns
CREATE TABLE IF NOT EXISTS interactions (
  id TEXT PRIMARY KEY,
  action TEXT,
  who TEXT,
  what TEXT,
  time TEXT
) WITH default_time_to_live = 7776000;  -- 90 days TTL

-- Indexes for querying
CREATE INDEX IF NOT EXISTS idx_action ON interactions (action);
CREATE INDEX IF NOT EXISTS idx_who ON interactions (who);
