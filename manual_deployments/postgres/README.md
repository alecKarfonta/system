# PostgreSQL Setup

PostgreSQL database server for ML development and data management.

## 📋 Overview
PostgreSQL provides a robust, scalable database solution for ML applications. This component sets up PostgreSQL server with optimizations for ML workloads, including extensions for vector operations and data science workflows.

## 🚀 Quick Start
```bash
# Install PostgreSQL
./install_postgres.sh

# Verify installation
sudo systemctl status postgresql
psql --version
```

## 📂 Files
- `install_postgres.sh` - PostgreSQL installation script
- `test_postgres.sh` - Database testing script
- `commands.md` - Common PostgreSQL commands
- `configs/` - Configuration files and examples

## 🛠️ Installation

### Automatic Installation (Recommended)
```bash
./install_postgres.sh
```

### Manual Installation Steps

#### Ubuntu/Debian
```bash
# Update package lists
sudo apt update

# Install PostgreSQL and extensions
sudo apt install -y postgresql postgresql-contrib postgresql-client

# Install additional extensions
sudo apt install -y postgresql-plpython3-14 postgresql-14-postgis-3

# Start and enable service
sudo systemctl start postgresql
sudo systemctl enable postgresql

# Secure installation
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'your_secure_password';"
```

#### macOS
```bash
# Install via Homebrew
brew install postgresql@14

# Start service
brew services start postgresql@14

# Create database cluster (if needed)
initdb --locale=C -E UTF-8 /opt/homebrew/var/postgresql@14
```

## 🔧 Configuration

### Basic Setup
```bash
# Switch to postgres user
sudo -u postgres psql

# Create development database
CREATE DATABASE ml_dev;

# Create application user
CREATE USER ml_user WITH PASSWORD 'secure_password';

# Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ml_dev TO ml_user;

# Exit psql
\q
```

### Performance Tuning
```bash
# Edit PostgreSQL configuration
sudo nano /etc/postgresql/14/main/postgresql.conf

# Key settings for ML workloads:
# shared_buffers = 256MB          # 25% of RAM
# effective_cache_size = 1GB      # 50% of RAM
# work_mem = 64MB                 # For complex queries
# maintenance_work_mem = 256MB    # For maintenance operations
# max_connections = 100           # Adjust based on needs
# checkpoint_completion_target = 0.9
# wal_buffers = 16MB
# default_statistics_target = 500 # For better query planning
```

### Authentication Setup
```bash
# Edit pg_hba.conf for authentication
sudo nano /etc/postgresql/14/main/pg_hba.conf

# Add local connections (development)
# local   all             ml_user                                md5
# host    ml_dev          ml_user         127.0.0.1/32           md5

# Restart PostgreSQL
sudo systemctl restart postgresql
```

## 🧪 Testing
```bash
# Test PostgreSQL installation
./test_postgres.sh

# Manual tests
psql -h localhost -U ml_user -d ml_dev -c "SELECT version();"

# Test with Python
python3 -c "
import psycopg2
conn = psycopg2.connect(
    host='localhost',
    database='ml_dev',
    user='ml_user',
    password='secure_password'
)
print('PostgreSQL connection successful!')
conn.close()
"
```

## 📚 Usage Examples

### Basic Database Operations
```sql
-- Connect to database
\c ml_dev

-- Create table for ML experiments
CREATE TABLE experiments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    model_type VARCHAR(50),
    parameters JSONB,
    metrics JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert experiment data
INSERT INTO experiments (name, model_type, parameters, metrics) VALUES
('bert_classification', 'transformer', 
 '{"learning_rate": 0.001, "batch_size": 32}',
 '{"accuracy": 0.95, "f1_score": 0.93}');

-- Query experiments
SELECT name, metrics->>'accuracy' as accuracy 
FROM experiments 
WHERE model_type = 'transformer';
```

### ML-Specific Extensions
```sql
-- Install vector extension (for embeddings)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table for embeddings
CREATE TABLE document_embeddings (
    id SERIAL PRIMARY KEY,
    document_id INTEGER,
    embedding vector(768),  -- 768-dimensional embeddings
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert embedding
INSERT INTO document_embeddings (document_id, embedding) VALUES
(1, '[0.1, 0.2, 0.3, ...]');  -- Your actual embedding vector

-- Similarity search
SELECT document_id, 1 - (embedding <=> '[0.1, 0.2, 0.3, ...]') as similarity
FROM document_embeddings
ORDER BY embedding <=> '[0.1, 0.2, 0.3, ...]'
LIMIT 10;
```

### Time Series Data
```sql
-- Install TimescaleDB extension (optional)
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- Create hypertable for metrics
CREATE TABLE model_metrics (
    time TIMESTAMPTZ NOT NULL,
    model_id INTEGER NOT NULL,
    metric_name VARCHAR(50) NOT NULL,
    value DOUBLE PRECISION NOT NULL
);

-- Convert to hypertable
SELECT create_hypertable('model_metrics', 'time');

-- Insert time series data
INSERT INTO model_metrics (time, model_id, metric_name, value) VALUES
(NOW(), 1, 'loss', 0.25),
(NOW(), 1, 'accuracy', 0.95);
```

## 🔍 Troubleshooting

### Issue: Connection refused
**Solution:**
```bash
# Check if PostgreSQL is running
sudo systemctl status postgresql

# Start service if stopped
sudo systemctl start postgresql

# Check port binding
sudo netstat -tulpn | grep :5432

# Check configuration
sudo -u postgres psql -c "SHOW listen_addresses;"
```

### Issue: Authentication failed
**Solution:**
```bash
# Check pg_hba.conf
sudo cat /etc/postgresql/14/main/pg_hba.conf

# Reset postgres password
sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'newpassword';"

# Reload configuration
sudo systemctl reload postgresql
```

### Issue: Out of disk space
**Solution:**
```bash
# Check database sizes
sudo -u postgres psql -c "
SELECT pg_database.datname, 
       pg_size_pretty(pg_database_size(pg_database.datname)) AS size
FROM pg_database;
"

# Clean up logs
sudo find /var/log/postgresql -name "*.log" -type f -mtime +7 -delete

# Vacuum databases
sudo -u postgres psql -d ml_dev -c "VACUUM FULL;"
```

### Issue: Poor performance
**Solution:**
```bash
# Analyze slow queries
sudo -u postgres psql -c "
SELECT query, mean_time, calls 
FROM pg_stat_statements 
ORDER BY mean_time DESC 
LIMIT 10;
"

# Update statistics
sudo -u postgres psql -d ml_dev -c "ANALYZE;"

# Check for missing indexes
# Use explain analyze on slow queries
```

## 📖 Advanced Configuration

### Backup and Recovery
```bash
# Create backup
pg_dump -h localhost -U ml_user ml_dev > ml_dev_backup.sql

# Automated backup script
#!/bin/bash
BACKUP_DIR="/var/backups/postgresql"
DATE=$(date +"%Y%m%d_%H%M%S")
pg_dump -h localhost -U ml_user ml_dev | gzip > "$BACKUP_DIR/ml_dev_$DATE.sql.gz"

# Restore from backup
psql -h localhost -U ml_user ml_dev < ml_dev_backup.sql
```

### Replication Setup
```bash
# Primary server configuration
# In postgresql.conf:
# wal_level = replica
# max_wal_senders = 3
# max_replication_slots = 3

# Create replication user
sudo -u postgres psql -c "
CREATE USER replica_user REPLICATION LOGIN PASSWORD 'replica_password';
"

# Standby server setup
pg_basebackup -h primary_server -D /var/lib/postgresql/14/standby -U replica_user -P -v -R -X stream -C -S standby_slot
```

### Connection Pooling
```bash
# Install PgBouncer
sudo apt install pgbouncer

# Configure PgBouncer
sudo nano /etc/pgbouncer/pgbouncer.ini

# [databases]
# ml_dev = host=localhost port=5432 dbname=ml_dev
# 
# [pgbouncer]
# pool_mode = transaction
# max_client_conn = 200
# default_pool_size = 25

# Start PgBouncer
sudo systemctl start pgbouncer
sudo systemctl enable pgbouncer
```

## 📊 Monitoring and Maintenance

### Monitoring Queries
```sql
-- Active connections
SELECT count(*) FROM pg_stat_activity;

-- Database sizes
SELECT datname, pg_size_pretty(pg_database_size(datname)) 
FROM pg_database;

-- Table sizes
SELECT schemaname, tablename, 
       pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as size
FROM pg_tables 
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;

-- Lock information
SELECT * FROM pg_locks WHERE NOT granted;
```

### Maintenance Tasks
```bash
# Regular maintenance script
#!/bin/bash
# vacuum_and_analyze.sh

# Connect and run maintenance
sudo -u postgres psql -d ml_dev -c "
VACUUM ANALYZE;
REINDEX DATABASE ml_dev;
"

# Update statistics
sudo -u postgres psql -d ml_dev -c "
SELECT schemaname, tablename, n_tup_ins, n_tup_upd, n_tup_del, last_vacuum, last_analyze
FROM pg_stat_user_tables;
"
```

## 📚 Python Integration

### Using psycopg2
```python
import psycopg2
import pandas as pd

# Connection
conn = psycopg2.connect(
    host="localhost",
    database="ml_dev",
    user="ml_user",
    password="secure_password"
)

# Execute query
df = pd.read_sql_query("SELECT * FROM experiments", conn)

# Insert data
cur = conn.cursor()
cur.execute("""
    INSERT INTO experiments (name, parameters, metrics) 
    VALUES (%s, %s, %s)
""", ("new_experiment", '{"lr": 0.01}', '{"acc": 0.89}'))
conn.commit()

conn.close()
```

### Using SQLAlchemy
```python
from sqlalchemy import create_engine
import pandas as pd

# Create engine
engine = create_engine('postgresql://ml_user:secure_password@localhost/ml_dev')

# Read data
df = pd.read_sql_table('experiments', engine)

# Write data
df.to_sql('new_table', engine, if_exists='replace', index=False)
```

## 📖 Additional Resources
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [PostgreSQL Performance Tuning](https://wiki.postgresql.org/wiki/Performance_Optimization)
- [TimescaleDB for Time Series](https://www.timescale.com/)
- [pgvector for Embeddings](https://github.com/pgvector/pgvector)

---
**Next Steps**: After PostgreSQL setup, consider integrating with [Jupyter](../jupyter/) for data analysis or [Docker](../docker/) for containerized deployments. 