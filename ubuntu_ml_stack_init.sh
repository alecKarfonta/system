#!/bin/bash

# Ubuntu ML/AI Development Stack Initialization Script
# Compatible with Ubuntu 24.04 LTS (Noble)
# Supports NVIDIA RTX 5090 and modern GPU setups
# Author: Generated for Alec's development environment
# Date: $(date)

set -e  # Exit on any error
set -u  # Exit on undefined variables

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
NVIDIA_DRIVER_VERSION="575"  # Open source driver version
DOCKER_COMPOSE_VERSION="v2.38.2"
PYTHON_VERSION="3.12"
NODEJS_VERSION="20"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        error "This script should not be run as root. Please run as a regular user with sudo privileges."
    fi
}

# Check Ubuntu version
check_ubuntu_version() {
    log "Checking Ubuntu version..."
    if ! lsb_release -d | grep -q "Ubuntu 24.04"; then
        warn "This script is optimized for Ubuntu 24.04 LTS. Proceeding anyway..."
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    sudo apt update
    sudo apt upgrade -y
    sudo apt autoremove -y
    sudo apt autoclean
}

# Install essential development tools
install_dev_tools() {
    log "Installing essential development tools..."
    sudo apt install -y \
        curl \
        wget \
        git \
        vim \
        htop \
        tree \
        unzip \
        software-properties-common \
        apt-transport-https \
        ca-certificates \
        gnupg \
        lsb-release \
        build-essential \
        python3-dev \
        python3-pip \
        python3-venv \
        pkg-config \
        libssl-dev \
        libffi-dev \
        libbz2-dev \
        libreadline-dev \
        libsqlite3-dev \
        libncurses5-dev \
        libncursesw5-dev \
        xz-utils \
        tk-dev \
        libxml2-dev \
        libxmlsec1-dev \
        libffi-dev \
        liblzma-dev
}

# Install Python and pip
setup_python() {
    log "Setting up Python ${PYTHON_VERSION}..."
    
    # Ensure python3 points to the right version
    python3 --version
    pip3 --version
    
    # Install common Python packages
    pip3 install --user --upgrade \
        pip \
        setuptools \
        wheel \
        virtualenv \
        openai \
        requests \
        numpy \
        pandas \
        matplotlib \
        jupyter \
        ipython
}

# Install Node.js
install_nodejs() {
    log "Installing Node.js ${NODEJS_VERSION}..."
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_${NODEJS_VERSION}.x | sudo -E bash -
    sudo apt install -y nodejs
    
    # Verify installation
    node --version
    npm --version
    
    # Install common global packages
    sudo npm install -g yarn pm2
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Remove old versions
    sudo apt remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Add Docker's official GPG key
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Add Docker repository
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    sudo apt update
    sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    
    # Add user to docker group
    sudo usermod -aG docker $USER
    
    # Start and enable Docker
    sudo systemctl start docker
    sudo systemctl enable docker
    
    log "Docker installed. You may need to log out and back in for group changes to take effect."
}

# Install NVIDIA drivers (open source)
install_nvidia_driver() {
    log "Installing NVIDIA driver (open source version ${NVIDIA_DRIVER_VERSION})..."
    
    # Check if NVIDIA GPU is present
    if ! lspci | grep -i nvidia > /dev/null; then
        warn "No NVIDIA GPU detected. Skipping NVIDIA driver installation."
        return 0
    fi
    
    # Remove existing proprietary drivers
    sudo apt remove --purge -y nvidia-* libnvidia-* 2>/dev/null || true
    
    # Install open source NVIDIA driver
    sudo apt update
    sudo apt install -y \
        nvidia-driver-${NVIDIA_DRIVER_VERSION}-open \
        nvidia-firmware-${NVIDIA_DRIVER_VERSION}-${NVIDIA_DRIVER_VERSION}.64.03 \
        nvidia-settings
    
    log "NVIDIA driver installed. A reboot will be required."
}

# Install NVIDIA Container Toolkit
install_nvidia_container_toolkit() {
    log "Installing NVIDIA Container Toolkit..."
    
    # Check if NVIDIA GPU is present
    if ! lspci | grep -i nvidia > /dev/null; then
        warn "No NVIDIA GPU detected. Skipping NVIDIA Container Toolkit installation."
        return 0
    fi
    
    # Add NVIDIA Container Toolkit repository
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    
    curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list
    
    # Install NVIDIA Container Toolkit
    sudo apt update
    sudo apt install -y nvidia-container-toolkit
    
    # Configure Docker to use NVIDIA runtime
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
    
    log "NVIDIA Container Toolkit installed and configured."
}

# Setup development directories
setup_dev_directories() {
    log "Setting up development directories..."
    
    mkdir -p ~/git
    mkdir -p ~/projects
    mkdir -p ~/scripts
    mkdir -p ~/.local/bin
    
    # Create useful aliases
    cat >> ~/.bashrc << 'EOF'

# Custom aliases for ML development
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias grep='grep --color=auto'
alias dcup='docker compose up -d'
alias dcdown='docker compose down'
alias dclogs='docker compose logs -f'
alias dcps='docker compose ps'
alias dcbuild='docker compose build'
alias nvidia-status='nvidia-smi'
alias gpu-status='nvidia-smi'

# Add ~/.local/bin to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
EOF
}

# Install Ollama (optional)
install_ollama() {
    read -p "Install Ollama? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing Ollama..."
        curl -fsSL https://ollama.ai/install.sh | sh
        
        # Add user to ollama group if it exists
        if getent group ollama > /dev/null 2>&1; then
            sudo usermod -aG ollama $USER
        fi
        
        log "Ollama installed. Start it with: systemctl --user start ollama"
    fi
}

# Install Visual Studio Code (optional)
install_vscode() {
    read -p "Install Visual Studio Code? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log "Installing Visual Studio Code..."
        
        # Add Microsoft GPG key and repository
        wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
        sudo install -o root -g root -m 644 packages.microsoft.gpg /etc/apt/trusted.gpg.d/
        sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/trusted.gpg.d/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
        
        sudo apt update
        sudo apt install -y code
        
        log "Visual Studio Code installed."
    fi
}

# Clone the Talker project
clone_talker_project() {
    log "Cloning the Talker ML/AI project..."
    
    mkdir -p ~/git
    cd ~/git
    
    if [ ! -d "talker" ]; then
        git clone https://github.com/alecKarfonta/talker.git
        log "✓ Talker project cloned to ~/git/talker"
    else
        log "✓ Talker project already exists at ~/git/talker"
        cd talker
        git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || log "Could not pull latest changes"
    fi
    
    cd ~/git/talker
    
    # Make scripts executable
    if [ -f "run.sh" ]; then
        chmod +x run.sh
        log "✓ Made run.sh executable"
    fi
    
    if [ -f "build.sh" ]; then
        chmod +x build.sh
        log "✓ Made build.sh executable"
    fi
    
    # Make ollama scripts executable
    if [ -f "ollama_api/start.sh" ]; then
        chmod +x ollama_api/start.sh
        log "✓ Made ollama_api/start.sh executable"
    fi
    
    if [ -f "ollama_api/test_ollama.py" ]; then
        chmod +x ollama_api/test_ollama.py
        log "✓ Made ollama_api/test_ollama.py executable"
    fi
    
    if [ -f "ollama_api/test_large_context.py" ]; then
        chmod +x ollama_api/test_large_context.py
        log "✓ Made ollama_api/test_large_context.py executable"
    fi
    
    log "Talker project ready at ~/git/talker"
    log "Repository: https://github.com/alecKarfonta/talker"
}

# System optimization for ML workloads
optimize_system() {
    log "Applying system optimizations for ML workloads..."
    
    # Increase file descriptor limits
    echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
    echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
    
    # Optimize shared memory for containers
    echo "tmpfs /dev/shm tmpfs defaults,noexec,nosuid,size=50% 0 0" | sudo tee -a /etc/fstab
    
    # Enable performance governor (if available)
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
    fi
}

# Final system checks
final_checks() {
    log "Performing final system checks..."
    
    # Check Docker
    if docker --version > /dev/null 2>&1; then
        log "✓ Docker is installed: $(docker --version)"
    else
        warn "✗ Docker installation may have failed"
    fi
    
    # Check Docker Compose
    if docker compose version > /dev/null 2>&1; then
        log "✓ Docker Compose is installed: $(docker compose version)"
    else
        warn "✗ Docker Compose installation may have failed"
    fi
    
    # Check NVIDIA driver
    if nvidia-smi > /dev/null 2>&1; then
        log "✓ NVIDIA driver is working: $(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits)"
    else
        warn "✗ NVIDIA driver may not be working (this is OK if no NVIDIA GPU is present)"
    fi
    
    # Check NVIDIA Container Toolkit
    if nvidia-container-toolkit --version > /dev/null 2>&1; then
        log "✓ NVIDIA Container Toolkit is installed: $(nvidia-container-toolkit --version | head -1)"
    else
        warn "✗ NVIDIA Container Toolkit may not be installed"
    fi
    
    # Check Python
    if python3 --version > /dev/null 2>&1; then
        log "✓ Python is installed: $(python3 --version)"
    else
        warn "✗ Python installation may have failed"
    fi
    
    # Check Node.js
    if node --version > /dev/null 2>&1; then
        log "✓ Node.js is installed: $(node --version)"
    else
        warn "✗ Node.js installation may have failed"
    fi
}

# Main execution
main() {
    log "Starting Ubuntu ML/AI Development Stack Installation"
    log "=================================================="
    
    check_root
    check_ubuntu_version
    
    # Core system setup
    update_system
    install_dev_tools
    setup_python
    install_nodejs
    
    # Docker installation
    install_docker
    
    # NVIDIA setup (if applicable)
    install_nvidia_driver
    install_nvidia_container_toolkit
    
    # Development environment
    setup_dev_directories
    
    # Optional components
    install_ollama
    install_vscode
    
    # Final setup
    clone_talker_project
    optimize_system
    final_checks
    
    log "=================================================="
    log "Installation completed!"
    log ""
    log "IMPORTANT NEXT STEPS:"
    log "1. Reboot your system to ensure all drivers and kernel modules are loaded"
    log "2. Log out and back in to apply Docker group membership"
    log "3. Test NVIDIA setup with: nvidia-smi"
    log "4. Test Docker with: docker run hello-world"
    log "5. Test NVIDIA Container Toolkit with: docker run --rm --runtime=nvidia --gpus all nvidia/cuda:11.0-base nvidia-smi"
    log "6. Configure Talker project:"
    log "   cd ~/git/talker"
    log "   cp env_template.txt .env  # Edit with your settings"
    log "   docker compose build"
    log "   docker compose up -d"
    log ""
    log "Your system is now ready for ML/AI development!"
    
    read -p "Reboot now? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo reboot
    fi
}

# Script execution with error handling
trap 'error "Script failed at line $LINENO"' ERR

# Allow script to be sourced for testing individual functions
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi