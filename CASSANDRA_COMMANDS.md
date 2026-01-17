# Cassandra Commands Reference

Useful commands to check and interact with your Cassandra instance.

## Quick Access

### Connect to Cassandra CLI (cqlsh)
```bash
docker exec -it task9-cassandra cqlsh
```

### Connect with explicit host and port
```bash
docker exec -it task9-cassandra cqlsh localhost 9042
```

---

## Cluster & Health Checks

### Check if Cassandra container is running
```bash
docker ps | grep cassandra
```

### Check container logs
```bash
docker logs task9-cassandra
```

### Follow logs in real-time
```bash
docker logs -f task9-cassandra
```

### Check Cassandra nodetool status
```bash
docker exec -it task9-cassandra nodetool status
```

### Check cluster information
```bash
docker exec -it task9-cassandra nodetool describecluster
```

### Check ring status (data distribution)
```bash
docker exec -it task9-cassandra nodetool ring
```

### Check compaction status
```bash
docker exec -it task9-cassandra nodetool compactionstats
```

### Check table statistics
```bash
docker exec -it task9-cassandra nodetool tablestats taskflow.interactions
```

---

## CQL Shell Commands (Inside cqlsh)

### List all keyspaces
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE KEYSPACES"
```

### Use the taskflow keyspace
```bash
docker exec -it task9-cassandra cqlsh -e "USE taskflow; DESCRIBE KEYSPACE;"
```

### List all tables in a keyspace
```bash
docker exec -it task9-cassandra cqlsh -e "USE taskflow; DESCRIBE TABLES;"
```

### Describe a specific table structure
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE TABLE taskflow.interactions"
```

### Show table indexes
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE INDEX taskflow.idx_action"
```

---

## Query Data

### View recent interactions (limit 20)
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT id, action, who, what, time FROM taskflow.interactions LIMIT 20"
```

### Count total events
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT COUNT(*) FROM taskflow.interactions"
```

### Get all login events
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT id, who, what, time FROM taskflow.interactions WHERE action = 'login' ALLOW FILTERING"
```

### Get events for a specific user
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT id, action, what, time FROM taskflow.interactions WHERE who = 'user@example.com' ALLOW FILTERING"
```

### Get events by action type
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT id, who, what, time FROM taskflow.interactions WHERE action = 'create' ALLOW FILTERING"
```

### Check if any data exists
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT * FROM taskflow.interactions LIMIT 1"
```

### Get all unique actions
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT DISTINCT action FROM taskflow.interactions ALLOW FILTERING"
```

---

## Interactive CQL Shell Session

### Start interactive session
```bash
docker exec -it task9-cassandra cqlsh
```

### Then inside cqlsh, run:
```sql
-- Use the keyspace
USE taskflow;

-- Show tables
DESCRIBE TABLES;

-- Describe table structure
DESCRIBE TABLE interactions;

-- View recent data
SELECT * FROM interactions LIMIT 10;

-- Count records
SELECT COUNT(*) FROM interactions;

-- Query by action (using index)
SELECT * FROM interactions WHERE action = 'login' ALLOW FILTERING;

-- Query by user (using index)
SELECT * FROM interactions WHERE who = 'user@example.com' ALLOW FILTERING;

-- Exit cqlsh
EXIT;
```

---

## Monitoring & Debugging

### Check table size on disk
```bash
docker exec -it task9-cassandra nodetool cfstats taskflow.interactions
```

### Check garbage collection stats
```bash
docker exec -it task9-cassandra nodetool gcstats
```

### Check network connectivity
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT release_version FROM system.local"
```

### Check keyspace replication settings
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT * FROM system_schema.keyspaces WHERE keyspace_name = 'taskflow'"
```

### Check table metadata
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT * FROM system_schema.tables WHERE keyspace_name = 'taskflow'"
```

### Check index information
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT * FROM system_schema.indexes WHERE keyspace_name = 'taskflow'"
```

---

## Troubleshooting

### Check if keyspace exists
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE KEYSPACE taskflow"
```

### Check if table exists
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE TABLE taskflow.interactions"
```

### Verify indexes are created
```bash
docker exec -it task9-cassandra cqlsh -e "DESCRIBE INDEX taskflow.idx_action; DESCRIBE INDEX taskflow.idx_who;"
```

### Test connection from host machine (if cqlsh is installed locally)
```bash
cqlsh localhost 9042
```

---

## Useful One-Liners

### Quick health check (all in one)
```bash
docker exec -it task9-cassandra cqlsh -e "SELECT release_version FROM system.local; DESCRIBE KEYSPACES; SELECT COUNT(*) FROM taskflow.interactions;"
```

### Monitor data growth
```bash
watch -n 2 'docker exec task9-cassandra cqlsh -e "SELECT COUNT(*) FROM taskflow.interactions"'
```

### View latest 5 events continuously
```bash
watch -n 1 'docker exec task9-cassandra cqlsh -e "SELECT id, action, who, time FROM taskflow.interactions LIMIT 5"'
```
