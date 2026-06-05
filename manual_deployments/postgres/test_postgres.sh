#!/bin/bash
# PostgreSQL Testing Script for ML Development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

echo -e "${BLUE}Testing PostgreSQL Installation${NC}"
echo "==============================="

# Configuration
DB_NAME="ml_dev"
DB_USER="ml_user"
DB_HOST="localhost"
DB_PORT="5432"

# Check for connection info file
if [[ -f "postgres_connection.txt" ]]; then
    print_info "Found connection info file"
else
    print_warning "Connection info file not found"
fi

# Test 1: PostgreSQL command exists
print_info "Test 1: Checking if psql command exists..."
if command -v psql >/dev/null 2>&1; then
    POSTGRES_VERSION=$(psql --version)
    print_success "PostgreSQL command found: $POSTGRES_VERSION"
else
    print_error "PostgreSQL command not found"
    exit 1
fi

# Test 2: PostgreSQL service is running
print_info "Test 2: Checking if PostgreSQL service is running..."
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    if systemctl is-active --quiet postgresql; then
        print_success "PostgreSQL service is running"
    else
        print_error "PostgreSQL service is not running"
        print_info "Try: sudo systemctl start postgresql"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if brew services list | grep postgresql | grep started >/dev/null 2>&1; then
        print_success "PostgreSQL service is running"
    else
        print_error "PostgreSQL service is not running"
        print_info "Try: brew services start postgresql@14"
        exit 1
    fi
fi

# Test 3: PostgreSQL is listening on port 5432
print_info "Test 3: Checking if PostgreSQL is listening on port 5432..."
if netstat -tuln 2>/dev/null | grep :5432 >/dev/null 2>&1 || ss -tuln 2>/dev/null | grep :5432 >/dev/null 2>&1; then
    print_success "PostgreSQL is listening on port 5432"
else
    print_warning "Cannot verify PostgreSQL is listening on port 5432"
fi

# Test 4: Default postgres user connection
print_info "Test 4: Testing default postgres user connection..."
if sudo -u postgres psql -c "SELECT version();" >/dev/null 2>&1; then
    print_success "Default postgres user connection works"
else
    print_error "Default postgres user connection failed"
    exit 1
fi

# Test 5: ML database exists
print_info "Test 5: Checking if ML database exists..."
if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw "$DB_NAME"; then
    print_success "Database '$DB_NAME' exists"
else
    print_error "Database '$DB_NAME' does not exist"
    exit 1
fi

# Test 6: ML user exists
print_info "Test 6: Checking if ML user exists..."
if sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$DB_USER'" | grep -q 1; then
    print_success "User '$DB_USER' exists"
else
    print_error "User '$DB_USER' does not exist"
    exit 1
fi

# Test 7: ML user can connect (requires password)
print_info "Test 7: Testing ML user connection..."
read -s -p "Enter password for user '$DB_USER': " DB_PASSWORD
echo

if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT current_user;" >/dev/null 2>&1; then
    print_success "ML user connection successful"
else
    print_error "ML user connection failed"
    print_info "Check password and authentication configuration"
    exit 1
fi

# Test 8: Basic SQL operations
print_info "Test 8: Testing basic SQL operations..."
TEST_TABLE="test_table_$$"
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
CREATE TABLE $TEST_TABLE (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO $TEST_TABLE (name) VALUES ('test');
SELECT * FROM $TEST_TABLE;
DROP TABLE $TEST_TABLE;
" >/dev/null 2>&1; then
    print_success "Basic SQL operations work"
else
    print_error "Basic SQL operations failed"
    exit 1
fi

# Test 9: JSON support
print_info "Test 9: Testing JSON support..."
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT '{\"key\": \"value\"}'::jsonb;
" >/dev/null 2>&1; then
    print_success "JSON support works"
else
    print_error "JSON support failed"
    exit 1
fi

# Test 10: UUID extension
print_info "Test 10: Testing UUID extension..."
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT uuid_generate_v4();
" >/dev/null 2>&1; then
    print_success "UUID extension works"
else
    print_warning "UUID extension not available (may need to install)"
fi

# Test 11: ML sample tables
print_info "Test 11: Checking ML sample tables..."
TABLES_EXIST=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -tAc "
SELECT COUNT(*) FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('experiments', 'model_versions', 'datasets');
")

if [[ "$TABLES_EXIST" == "3" ]]; then
    print_success "ML sample tables exist"
else
    print_warning "ML sample tables not found (expected: 3, found: $TABLES_EXIST)"
fi

# Test 12: Insert and query sample data
print_info "Test 12: Testing sample data operations..."
if PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
INSERT INTO experiments (name, model_type, parameters, metrics) VALUES 
('test_experiment', 'test_model', '{\"lr\": 0.01}', '{\"accuracy\": 0.95}');
SELECT name FROM experiments WHERE name = 'test_experiment';
DELETE FROM experiments WHERE name = 'test_experiment';
" >/dev/null 2>&1; then
    print_success "Sample data operations work"
else
    print_warning "Sample data operations failed (tables may not exist)"
fi

# Test 13: Python psycopg2 connection
print_info "Test 13: Testing Python psycopg2 connection..."
if command -v python3 >/dev/null 2>&1; then
    if python3 -c "
import psycopg2
conn = psycopg2.connect(
    host='$DB_HOST',
    database='$DB_NAME',
    user='$DB_USER',
    password='$DB_PASSWORD'
)
cur = conn.cursor()
cur.execute('SELECT version()')
cur.fetchone()
conn.close()
print('Python connection successful')
" 2>/dev/null; then
        print_success "Python psycopg2 connection works"
    else
        print_warning "Python psycopg2 connection failed (psycopg2 may not be installed)"
    fi
else
    print_warning "Python3 not found, skipping Python connection test"
fi

# Test 14: Configuration optimization check
print_info "Test 14: Checking configuration optimizations..."
SHARED_BUFFERS=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -tAc "SHOW shared_buffers;" 2>/dev/null || echo "unknown")
WORK_MEM=$(PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -tAc "SHOW work_mem;" 2>/dev/null || echo "unknown")

if [[ "$SHARED_BUFFERS" != "128MB" ]]; then
    print_success "shared_buffers optimized: $SHARED_BUFFERS"
else
    print_warning "shared_buffers using default: $SHARED_BUFFERS"
fi

if [[ "$WORK_MEM" != "4MB" ]]; then
    print_success "work_mem optimized: $WORK_MEM"
else
    print_warning "work_mem using default: $WORK_MEM"
fi

# Test 15: Performance test
print_info "Test 15: Basic performance test..."
START_TIME=$(date +%s%N)
PGPASSWORD="$DB_PASSWORD" psql -h "$DB_HOST" -U "$DB_USER" -d "$DB_NAME" -c "
SELECT COUNT(*) FROM generate_series(1, 10000);
" >/dev/null 2>&1
END_TIME=$(date +%s%N)
DURATION=$((($END_TIME - $START_TIME) / 1000000))

if [[ $DURATION -lt 1000 ]]; then
    print_success "Performance test passed (${DURATION}ms)"
else
    print_warning "Performance test slow (${DURATION}ms)"
fi

# Summary
echo ""
print_success "PostgreSQL testing completed!"
echo ""
print_info "PostgreSQL is ready for ML development"
print_info "Connection details:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Host: $DB_HOST"
echo "  Port: $DB_PORT"
echo ""
print_info "Next steps:"
echo "  - Create your ML tables and schemas"
echo "  - Configure backups"
echo "  - Monitor performance"
echo "  - Read documentation: postgres/README.md"
echo ""

exit 0 