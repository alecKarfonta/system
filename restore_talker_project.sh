#!/bin/bash

# Talker Project Restoration Script
# Restores the specific ML/AI stack for the Talker project
# Run this after running the main initialization script

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
info() { echo -e "${BLUE}[INFO] $1${NC}"; }
warn() { echo -e "${YELLOW}[WARN] $1${NC}"; }

log "Starting Talker project restoration..."

# Create project directory
PROJECT_DIR="$HOME/git/talker"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Clone the actual Talker repository
if [ ! -d ".git" ]; then
    info "Cloning Talker repository..."
    cd ~/git
    git clone https://github.com/alecKarfonta/talker.git
    cd talker
else
    info "Repository already exists, pulling latest changes..."
    git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || warn "Could not pull latest changes"
fi

# Directory structure is already in the repository
log "Using existing project structure from repository..."
log "Current directory: $(pwd)"
log "Project files: $(ls -la | wc -l) items"

# Use existing configuration files
log "Using existing project configuration files..."

# Check if required files exist
if [ -f "docker-compose.yaml" ]; then
    log "✓ Found docker-compose.yaml"
else
    warn "✗ docker-compose.yaml not found"
fi

if [ -f "env_template.txt" ]; then
    log "✓ Found env_template.txt"
    info "Copy env_template.txt to .env and customize your settings"
else
    warn "✗ env_template.txt not found - you may need to create environment variables manually"
fi

if [ -f "run.sh" ]; then
    chmod +x run.sh
    log "✓ Found and made run.sh executable"
fi

if [ -f "build.sh" ]; then
    chmod +x build.sh
    log "✓ Found and made build.sh executable"
fi

# Use existing docker-compose configurations
if [ -f "docker-compose.yaml" ]; then
    log "Using existing docker-compose.yaml for production stack"
fi

if [ -f "docker-compose.rtx5090.yaml" ]; then
    log "✓ Found RTX 5090 specific configuration"
    info "Use: docker compose -f docker-compose.rtx5090.yaml up -d"
fi

# Create development override if it doesn't exist
if [ ! -f "docker-compose.override.yml" ]; then
    log "Creating docker-compose.override.yml for local development..."
    cat > docker-compose.override.yml << 'EOF'
# Local development overrides
# This file is automatically loaded by docker compose
version: '3.8'

services:
  # Override for local development
  ollama_api:
    ports:
      - "11434:11434"  # Direct access for development
    
  postgres:
    ports:
      - "5432:5432"   # Standard PostgreSQL port for local access
      
  mongodb:
    ports:
      - "27017:27017" # Standard MongoDB port for local access
EOF
    log "✓ Created docker-compose.override.yml for local development"
fi

# .gitignore should already exist in the repository
if [ -f ".gitignore" ]; then
    log "✓ Using existing .gitignore"
else
    warn "✗ No .gitignore found - consider adding one"
fi

# README.md should already exist in the repository
if [ -f "README.md" ]; then
    log "✓ Using existing README.md"
else
    warn "✗ No README.md found"
fi

# Ollama API files should already exist in the repository
if [ -d "ollama_api" ]; then
    log "✓ Found existing ollama_api directory"
    if [ -f "ollama_api/Dockerfile" ]; then
        log "✓ Found existing Dockerfile"
    fi
    if [ -f "ollama_api/start.sh" ]; then
        chmod +x ollama_api/start.sh
        log "✓ Found and made start.sh executable"
    fi
    if [ -f "ollama_api/test_ollama.py" ]; then
        chmod +x ollama_api/test_ollama.py
        log "✓ Found and made test_ollama.py executable"
    fi
    if [ -f "ollama_api/test_large_context.py" ]; then
        chmod +x ollama_api/test_large_context.py
        log "✓ Found and made test_large_context.py executable"
    fi
else
    warn "✗ ollama_api directory not found"
fi

log "Talker project restored from repository!"
info "Next steps:"
echo "1. Copy env_template.txt to .env and customize your settings"
echo "2. Install Python dependencies: pip3 install -r requirements.txt"
echo "3. Build containers: docker compose build"
echo "4. Start development stack: docker compose up -d"
echo "5. Or start RTX 5090 optimized stack: docker compose -f docker-compose.rtx5090.yaml up -d"
echo "6. Test Ollama: cd ollama_api && python3 test_ollama.py"

log "Repository URL: https://github.com/alecKarfonta/talker"