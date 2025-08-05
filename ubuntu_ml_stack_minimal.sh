#!/bin/bash

# Minimal Ubuntu ML/AI Stack Initialization Script
# For quick setup without interactive prompts
# Compatible with Ubuntu 24.04 LTS

set -e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log() { echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"; }
error() { echo -e "${RED}ERROR: $1${NC}"; exit 1; }

# Check if running as root
[[ $EUID -eq 0 ]] && error "Don't run as root"

log "Starting minimal ML stack setup..."

# Update system
log "Updating packages..."
sudo apt update && sudo apt upgrade -y

# Install essentials
log "Installing development tools..."
sudo apt install -y curl wget git vim htop python3-dev python3-pip build-essential

# Install Docker
log "Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
sudo usermod -aG docker $USER
rm get-docker.sh

# Install NVIDIA drivers (if GPU present)
if lspci | grep -i nvidia > /dev/null; then
    log "Installing NVIDIA drivers..."
    sudo apt install -y nvidia-driver-575-open nvidia-container-toolkit
    sudo nvidia-ctk runtime configure --runtime=docker
    sudo systemctl restart docker
fi

# Python packages
log "Installing Python packages..."
pip3 install --user openai requests numpy pandas matplotlib jupyter

# Create dev directories
mkdir -p ~/git ~/projects

log "Minimal setup complete!"
log "Reboot recommended for GPU drivers."