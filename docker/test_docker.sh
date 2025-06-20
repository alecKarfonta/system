#!/bin/bash
# Docker Testing Script for ML Development

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

echo -e "${BLUE}Testing Docker Installation${NC}"
echo "=========================="

# Test 1: Docker command exists
print_info "Test 1: Checking if docker command exists..."
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    print_success "Docker command found: $DOCKER_VERSION"
else
    print_error "Docker command not found"
    exit 1
fi

# Test 2: Docker daemon is running
print_info "Test 2: Checking if Docker daemon is running..."
if docker info >/dev/null 2>&1; then
    print_success "Docker daemon is running"
else
    print_error "Docker daemon is not running or not accessible"
    print_info "Try: sudo systemctl start docker (Linux) or start Docker Desktop (macOS)"
    exit 1
fi

# Test 3: Docker version check
print_info "Test 3: Docker version compatibility..."
DOCKER_VERSION=$(docker version --format '{{.Server.Version}}' 2>/dev/null || echo "unknown")
if [[ "$DOCKER_VERSION" != "unknown" ]]; then
    print_success "Docker server version: $DOCKER_VERSION"
else
    print_warning "Could not determine Docker server version"
fi

# Test 4: Basic container execution
print_info "Test 4: Testing basic container execution..."
if docker run --rm hello-world >/dev/null 2>&1; then
    print_success "Basic container execution works"
else
    print_error "Basic container execution failed"
    exit 1
fi

# Test 5: Docker Compose availability
print_info "Test 5: Checking Docker Compose..."
if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_success "Docker Compose found: $COMPOSE_VERSION"
elif docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    print_success "Docker Compose plugin found: $COMPOSE_VERSION"
else
    print_warning "Docker Compose not found"
fi

# Test 6: Volume operations
print_info "Test 6: Testing volume operations..."
TEST_VOLUME="docker_test_volume_$$"
if docker volume create "$TEST_VOLUME" >/dev/null 2>&1; then
    if docker volume ls | grep -q "$TEST_VOLUME"; then
        print_success "Volume operations work"
        docker volume rm "$TEST_VOLUME" >/dev/null 2>&1
    else
        print_error "Volume creation verification failed"
        exit 1
    fi
else
    print_error "Volume creation failed"
    exit 1
fi

# Test 7: Network operations
print_info "Test 7: Testing network operations..."
TEST_NETWORK="docker_test_network_$$"
if docker network create "$TEST_NETWORK" >/dev/null 2>&1; then
    if docker network ls | grep -q "$TEST_NETWORK"; then
        print_success "Network operations work"
        docker network rm "$TEST_NETWORK" >/dev/null 2>&1
    else
        print_error "Network creation verification failed"
        exit 1
    fi
else
    print_error "Network creation failed"
    exit 1
fi

# Test 8: Image operations
print_info "Test 8: Testing image operations..."
if docker images >/dev/null 2>&1; then
    print_success "Image listing works"
else
    print_error "Image operations failed"
    exit 1
fi

# Test 9: Container with Python (ML relevant)
print_info "Test 9: Testing Python container execution..."
if docker run --rm python:3.10-slim python -c "print('Python in Docker works!')" >/dev/null 2>&1; then
    print_success "Python container execution works"
else
    print_warning "Python container test failed (may need internet connection)"
fi

# Test 10: GPU support (if available)
if command -v nvidia-smi >/dev/null 2>&1; then
    print_info "Test 10: Testing GPU support in Docker..."
    if docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
        print_success "GPU support in Docker works!"
    else
        print_warning "GPU support test failed (NVIDIA Container Toolkit may not be installed)"
    fi
else
    print_info "Test 10: Skipping GPU test (no NVIDIA GPU detected)"
fi

# Test 11: Docker daemon configuration
print_info "Test 11: Checking Docker daemon configuration..."
if [ -f /etc/docker/daemon.json ]; then
    print_success "Docker daemon configuration file exists"
else
    print_warning "Docker daemon configuration file not found"
fi

# Test 12: User permissions (Linux only)
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    print_info "Test 12: Checking user permissions..."
    if groups | grep -q docker; then
        print_success "User is in docker group"
    else
        print_warning "User is not in docker group (may need to logout/login)"
    fi
fi

# Summary
echo ""
print_success "Docker testing completed successfully!"
echo ""
print_info "Docker is ready for ML development"
print_info "Next steps:"
echo "  - Build ML containers: docker build -t ml-app ."
echo "  - Start development services: docker-compose up -d"
echo "  - Read documentation: docker/README.md"
echo ""

exit 0 