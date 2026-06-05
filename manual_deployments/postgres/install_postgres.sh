#!/bin/bash
# PostgreSQL Installation Script for ML Development

set -e  # Exit on any error
trap 'echo "PostgreSQL installation failed. Check the logs above."; exit 1' ERR

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

echo -e "${BLUE}PostgreSQL Installation for ML Development${NC}"
echo "=========================================="

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if command -v apt >/dev/null 2>&1; then
        DISTRO="ubuntu"
    elif command -v yum >/dev/null 2>&1; then
        DISTRO="centos"  
    else
        print_error "Unsupported Linux distribution"
        exit 1
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    DISTRO="macos"
else
    print_error "Unsupported operating system: $OSTYPE"
    exit 1
fi

print_info "Detected OS: $OS ($DISTRO)"

# Configuration variables
POSTGRES_VERSION="14"
DB_NAME="ml_dev"
DB_USER="ml_user"
DB_PASSWORD=""

# Get database password
while [[ -z "$DB_PASSWORD" ]]; do
    read -s -p "Enter password for database user '$DB_USER': " DB_PASSWORD
    echo
    if [[ -z "$DB_PASSWORD" ]]; then
        print_warning "Password cannot be empty. Please try again."
    fi
done

# Check if PostgreSQL is already installed
if command -v psql >/dev/null 2>&1; then
    POSTGRES_CURRENT_VERSION=$(psql --version | grep -oP '\d+\.\d+' | head -1)
    print_warning "PostgreSQL is already installed (version $POSTGRES_CURRENT_VERSION)"
    read -p "Do you want to continue with configuration? (y/n): " CONTINUE
    if [[ ! "$CONTINUE" =~ ^[Yy]$ ]]; then
        print_info "Skipping PostgreSQL installation"
        exit 0
    fi
fi

# Ubuntu/Debian Installation
if [[ "$DISTRO" == "ubuntu" ]]; then
    print_info "Installing PostgreSQL on Ubuntu/Debian..."
    
    # Update package lists
    sudo apt update
    
    # Install PostgreSQL and contrib packages
    sudo apt install -y postgresql postgresql-contrib postgresql-client
    
    # Install additional extensions for ML workloads
    sudo apt install -y postgresql-plpython3-$POSTGRES_VERSION postgresql-$POSTGRES_VERSION-postgis-3
    
    # Install development libraries
    sudo apt install -y libpq-dev postgresql-server-dev-$POSTGRES_VERSION
    
    print_success "PostgreSQL installed successfully"
    
# macOS Installation
elif [[ "$DISTRO" == "macos" ]]; then
    print_info "Installing PostgreSQL on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew is required for macOS installation"
        print_info "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # Install PostgreSQL
    brew install postgresql@$POSTGRES_VERSION
    
    # Install PostGIS for geospatial data
    brew install postgis
    
    print_success "PostgreSQL installed via Homebrew"
fi

# Start and enable PostgreSQL service
print_info "Starting PostgreSQL service..."
if [[ "$OS" == "linux" ]]; then
    sudo systemctl start postgresql
    sudo systemctl enable postgresql
    print_success "PostgreSQL service started and enabled"
elif [[ "$OS" == "macos" ]]; then
    brew services start postgresql@$POSTGRES_VERSION
    print_success "PostgreSQL service started"
fi

# Wait for PostgreSQL to be ready
print_info "Waiting for PostgreSQL to be ready..."
sleep 3

# Configure PostgreSQL for ML workloads
print_info "Configuring PostgreSQL for ML workloads..."

# Get PostgreSQL configuration directory
if [[ "$OS" == "linux" ]]; then
    PG_CONFIG_DIR="/etc/postgresql/$POSTGRES_VERSION/main"
    PG_DATA_DIR="/var/lib/postgresql/$POSTGRES_VERSION/main"
elif [[ "$OS" == "macos" ]]; then
    PG_CONFIG_DIR="$(brew --prefix)/var/postgresql@$POSTGRES_VERSION"
    PG_DATA_DIR="$PG_CONFIG_DIR"
fi

# Backup original configuration
if [[ "$OS" == "linux" ]] && [[ -f "$PG_CONFIG_DIR/postgresql.conf" ]]; then
    sudo cp "$PG_CONFIG_DIR/postgresql.conf" "$PG_CONFIG_DIR/postgresql.conf.backup"
    print_info "Backed up original postgresql.conf"
fi

# Create optimized configuration for ML workloads
print_info "Applying ML-optimized configuration..."

if [[ "$OS" == "linux" ]]; then
    sudo tee -a "$PG_CONFIG_DIR/postgresql.conf" <<EOF

# ML Development Optimizations
shared_buffers = 256MB                # 25% of RAM (adjust based on system)
effective_cache_size = 1GB            # 50% of RAM (adjust based on system)
work_mem = 64MB                        # For complex queries
maintenance_work_mem = 256MB           # For maintenance operations
max_connections = 100                  # Adjust based on needs
checkpoint_completion_target = 0.9     # Spread checkpoints
wal_buffers = 16MB                     # WAL buffer size
default_statistics_target = 500        # Better query planning
random_page_cost = 1.1                 # For SSDs
log_statement = 'mod'                  # Log modifications
log_duration = on                      # Log query duration
log_min_duration_statement = 1000      # Log slow queries (>1s)
EOF
fi

# Set up database and user
print_info "Setting up database and user..."

# Create database user and database
sudo -u postgres psql <<EOF
-- Create user
CREATE USER $DB_USER WITH PASSWORD '$DB_PASSWORD';

-- Create database
CREATE DATABASE $DB_NAME OWNER $DB_USER;

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;

-- Install useful extensions
\c $DB_NAME
CREATE EXTENSION IF NOT EXISTS plpgsql;
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Grant usage on schema
GRANT USAGE ON SCHEMA public TO $DB_USER;
GRANT CREATE ON SCHEMA public TO $DB_USER;

\q
EOF

print_success "Database '$DB_NAME' and user '$DB_USER' created"

# Configure authentication
print_info "Configuring authentication..."

if [[ "$OS" == "linux" ]]; then
    # Backup pg_hba.conf
    sudo cp "$PG_CONFIG_DIR/pg_hba.conf" "$PG_CONFIG_DIR/pg_hba.conf.backup"
    
    # Add local connection for ml_user
    sudo tee -a "$PG_CONFIG_DIR/pg_hba.conf" <<EOF

# ML Development - Local connections
local   $DB_NAME        $DB_USER                                md5
host    $DB_NAME        $DB_USER        127.0.0.1/32           md5
host    $DB_NAME        $DB_USER        ::1/128                md5
EOF
    
    print_success "Authentication configured"
fi

# Restart PostgreSQL to apply configuration changes
print_info "Restarting PostgreSQL to apply configuration..."
if [[ "$OS" == "linux" ]]; then
    sudo systemctl restart postgresql
elif [[ "$OS" == "macos" ]]; then
    brew services restart postgresql@$POSTGRES_VERSION
fi

# Wait for restart
sleep 3

# Test connection
print_info "Testing database connection..."
if PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" -c "SELECT version();" >/dev/null 2>&1; then
    print_success "Database connection test successful"
else
    print_error "Database connection test failed"
    exit 1
fi

# Install Python packages for PostgreSQL
print_info "Installing Python packages for PostgreSQL integration..."
if command -v pip >/dev/null 2>&1; then
    pip install psycopg2-binary sqlalchemy pandas
    print_success "Python PostgreSQL packages installed"
else
    print_warning "pip not found, skipping Python package installation"
fi

# Create sample ML tables
print_info "Creating sample ML tables..."
PGPASSWORD="$DB_PASSWORD" psql -h localhost -U "$DB_USER" -d "$DB_NAME" <<EOF
-- Experiments table for ML model tracking
CREATE TABLE IF NOT EXISTS experiments (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    model_type VARCHAR(50),
    parameters JSONB,
    metrics JSONB,
    dataset_info JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Model versions table
CREATE TABLE IF NOT EXISTS model_versions (
    id SERIAL PRIMARY KEY,
    experiment_id INTEGER REFERENCES experiments(id),
    version VARCHAR(20) NOT NULL,
    model_path TEXT,
    performance_metrics JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Dataset metadata table
CREATE TABLE IF NOT EXISTS datasets (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    file_path TEXT,
    size_bytes BIGINT,
    schema_info JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_experiments_created_at ON experiments(created_at);
CREATE INDEX IF NOT EXISTS idx_experiments_model_type ON experiments(model_type);
CREATE INDEX IF NOT EXISTS idx_model_versions_experiment_id ON model_versions(experiment_id);

-- Grant permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO $DB_USER;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO $DB_USER;
EOF

print_success "Sample ML tables created"

# Create connection information file
print_info "Creating connection information file..."
cat > postgres_connection.txt <<EOF
PostgreSQL Connection Information
=================================

Database: $DB_NAME
User: $DB_USER
Host: localhost
Port: 5432

Connection String (Python):
postgresql://$DB_USER:$DB_PASSWORD@localhost:5432/$DB_NAME

Connection Command:
psql -h localhost -U $DB_USER -d $DB_NAME

Environment Variables:
export PGHOST=localhost
export PGPORT=5432
export PGDATABASE=$DB_NAME
export PGUSER=$DB_USER
export PGPASSWORD=$DB_PASSWORD
EOF

print_success "Connection information saved to postgres_connection.txt"

echo ""
print_success "PostgreSQL installation and configuration complete!"
echo ""
print_info "Database Details:"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo "  Host: localhost"
echo "  Port: 5432"
echo ""
print_info "Next steps:"
echo "  1. Test connection: psql -h localhost -U $DB_USER -d $DB_NAME"
echo "  2. Install additional extensions as needed"
echo "  3. Configure backup strategy"
echo "  4. Read documentation: postgres/README.md"
echo ""
print_warning "Keep your database password secure!"
echo ""

exit 0 