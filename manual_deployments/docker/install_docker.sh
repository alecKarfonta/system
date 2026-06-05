#!/bin/bash
# Docker Installation Script for ML Development

set -e  # Exit on any error
trap 'echo "Docker installation failed. Check the logs above."; exit 1' ERR

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

echo -e "${BLUE}Docker Installation for ML Development${NC}"
echo "======================================="

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

# Check if Docker is already installed
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | sed 's/,//')
    print_warning "Docker is already installed (version $DOCKER_VERSION)"
    read -p "Do you want to reinstall Docker? (y/n): " REINSTALL
    if [[ ! "$REINSTALL" =~ ^[Yy]$ ]]; then
        print_info "Skipping Docker installation"
        exit 0
    fi
fi

# Ubuntu/Debian Installation
if [[ "$DISTRO" == "ubuntu" ]]; then
    print_info "Installing Docker on Ubuntu/Debian..."
    
    # Remove old versions
    sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install prerequisites
    sudo apt-get update
    sudo apt-get install -y \
        ca-certificates \
        curl \
        gnupg2 \
        software-properties-common \
        apt-transport-https \
        lsb-release
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    print_success "Docker Engine installed successfully"
    
# macOS Installation
elif [[ "$DISTRO" == "macos" ]]; then
    print_info "Installing Docker on macOS..."
    
    # Check if Homebrew is installed
    if ! command -v brew >/dev/null 2>&1; then
        print_error "Homebrew is required for macOS installation"
        print_info "Install Homebrew first: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
        exit 1
    fi
    
    # Install Docker Desktop
    brew install --cask docker
    
    print_success "Docker Desktop installed via Homebrew"
    print_warning "Please start Docker Desktop manually from Applications"
fi

# Add user to docker group (Linux only)
if [[ "$OS" == "linux" ]]; then
    print_info "Adding user to docker group..."
    sudo usermod -aG docker $USER
    print_success "User added to docker group"
    print_warning "You need to log out and log back in (or run 'newgrp docker') for group changes to take effect"
fi

# Start and enable Docker service (Linux only)
if [[ "$OS" == "linux" ]]; then
    print_info "Starting Docker service..."
    sudo systemctl start docker
    sudo systemctl enable docker
    print_success "Docker service started and enabled"
fi

# Test Docker installation
print_info "Testing Docker installation..."
if [[ "$OS" == "linux" ]]; then
    # Use newgrp to test with new group membership
    sudo -u $USER newgrp docker <<EOF
docker --version
docker run --rm hello-world >/dev/null 2>&1
EOF
else
    # For macOS, Docker might not be started yet
    sleep 5
    docker --version 2>/dev/null || print_warning "Docker Desktop may need to be started manually"
fi

print_success "Docker installation completed!"

# Install Docker Compose if not available
if ! command -v docker-compose >/dev/null 2>&1; then
    print_info "Installing Docker Compose..."
    if [[ "$OS" == "linux" ]]; then
        # Install docker-compose-plugin provides docker-compose command
        sudo apt-get install -y docker-compose-plugin
    else
        brew install docker-compose
    fi
    print_success "Docker Compose installed"
fi

# Create Docker daemon configuration for ML workloads
print_info "Configuring Docker daemon for ML workloads..."
sudo mkdir -p /etc/docker

# Create daemon.json with ML-optimized settings
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ],
  "default-runtime": "runc"
}
EOF

if [[ "$OS" == "linux" ]]; then
    sudo systemctl restart docker
    print_success "Docker daemon configured and restarted"
fi

# Check for GPU support
if command -v nvidia-smi >/dev/null 2>&1; then
    print_info "NVIDIA GPU detected. Installing NVIDIA Container Toolkit..."
    
    # Install NVIDIA Container Toolkit (Ubuntu only)
    if [[ "$DISTRO" == "ubuntu" ]]; then
        distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
        curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
        curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
            sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
            sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
        
        sudo apt-get update
        sudo apt-get install -y nvidia-container-toolkit
        
        # Configure Docker daemon for GPU
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
        
        print_success "NVIDIA Container Toolkit installed and configured"
        
        # Test GPU support
        print_info "Testing GPU support in Docker..."
        if sudo -u $USER newgrp docker <<< "docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi" >/dev/null 2>&1; then
            print_success "GPU support in Docker is working!"
        else
            print_warning "GPU support test failed. This is normal if no NVIDIA GPU is available."
        fi
    else
        print_warning "NVIDIA Container Toolkit installation not supported on macOS"
    fi
else
    print_info "No NVIDIA GPU detected, skipping GPU setup"
fi

echo ""
print_success "Docker installation complete!"
echo ""
print_info "Next steps:"
echo "1. Log out and log back in (Linux) or restart Docker Desktop (macOS)"
echo "2. Test Docker with: docker run hello-world"
echo "3. Start ML development stack: docker-compose up -d"
echo "4. See documentation at: docker/README.md"
echo ""

exit 0 