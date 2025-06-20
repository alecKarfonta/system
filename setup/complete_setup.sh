#!/bin/bash
# Complete ML Development Environment Setup Script
# This script orchestrates setup of all components in the correct order

set -e  # Exit on any error
trap 'echo "Setup failed. Check the logs above."; exit 1' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Progress tracking
STEP=1
TOTAL_STEPS=10

print_step() {
    echo -e "\n${BLUE}=== Step $STEP/$TOTAL_STEPS: $1 ===${NC}"
    ((STEP++))
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if script is run from correct directory
if [[ ! -f "README.md" ]] || [[ ! -d "setup" ]]; then
    print_error "Please run this script from the repository root directory"
    exit 1
fi

echo -e "${BLUE}"
cat << "EOF"
╔════════════════════════════════════════════════════════╗
║        ML Development Environment Setup                ║
║        Complete Installation Script                    ║
╚════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Detect OS
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    OS="linux"
    if command -v apt >/dev/null 2>&1; then
        DISTRO="ubuntu"
    elif command -v yum >/dev/null 2>&1; then
        DISTRO="centos"
    else
        DISTRO="unknown"
    fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
    OS="macos"
    DISTRO="macos"
else
    OS="unknown"
    DISTRO="unknown"
fi

echo -e "Detected OS: ${GREEN}$OS ($DISTRO)${NC}"

# User preferences
echo -e "\n${YELLOW}Configuration Options:${NC}"
read -p "Install NVIDIA/CUDA support? (y/n): " INSTALL_CUDA
read -p "Install full ML stack (vLLM, PyTorch)? (y/n): " INSTALL_ML
read -p "Install Jupyter Lab/Notebook? (y/n): " INSTALL_JUPYTER
read -p "Install Docker services? (y/n): " INSTALL_DOCKER
read -p "Install Kubernetes? (y/n): " INSTALL_K8S
read -p "Setup shell environment (Zsh)? (y/n): " INSTALL_SHELL

# Step 1: System Prerequisites
print_step "Installing System Prerequisites"
if [[ "$OS" == "linux" ]]; then
    if [[ "$DISTRO" == "ubuntu" ]]; then
        sudo apt update
        sudo apt install -y curl wget git build-essential software-properties-common
        print_success "Ubuntu prerequisites installed"
    fi
elif [[ "$OS" == "macos" ]]; then
    if ! command -v brew >/dev/null 2>&1; then
        print_warning "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    brew install git curl wget
    print_success "macOS prerequisites installed"
fi

# Step 2: Git Configuration
print_step "Configuring Git"
if [[ -f "setup/git.sh" ]]; then
    bash setup/git.sh
    print_success "Git configured"
else
    print_warning "Git setup script not found, skipping..."
fi

# Step 3: Python Environment (Conda)
print_step "Setting up Python Environment (Conda)"
if [[ -f "anaconda/install_conda.sh" ]]; then
    bash anaconda/install_conda.sh
    source ~/miniconda3/bin/activate
    print_success "Conda installed and configured"
else
    print_warning "Conda setup script not found, skipping..."
fi

# Step 4: Shell Environment
if [[ "$INSTALL_SHELL" =~ ^[Yy]$ ]]; then
    print_step "Setting up Shell Environment"
    if [[ -f "zsh/setup_zsh.sh" ]]; then
        bash zsh/setup_zsh.sh
        print_success "Zsh environment configured"
    else
        print_warning "Zsh setup script not found, skipping..."
    fi
fi

# Step 5: Docker
if [[ "$INSTALL_DOCKER" =~ ^[Yy]$ ]]; then
    print_step "Installing Docker"
    if [[ "$OS" == "linux" ]]; then
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $USER
        print_success "Docker installed (logout/login required for group permissions)"
    elif [[ "$OS" == "macos" ]]; then
        brew install docker docker-compose
        print_success "Docker installed via Homebrew"
    fi
fi

# Step 6: NVIDIA/CUDA
if [[ "$INSTALL_CUDA" =~ ^[Yy]$ ]]; then
    print_step "Installing NVIDIA Drivers and CUDA"
    if [[ -f "nvidia/nvidia.sh" ]]; then
        bash nvidia/nvidia.sh
        print_success "NVIDIA/CUDA setup completed"
    else
        print_warning "NVIDIA setup script not found, skipping..."
    fi
fi

# Step 7: Machine Learning Stack
if [[ "$INSTALL_ML" =~ ^[Yy]$ ]]; then
    print_step "Installing ML Stack (PyTorch, vLLM)"
    if [[ -f "ml/install_vllm.sh" ]]; then
        bash ml/install_vllm.sh
        print_success "ML stack installed"
    else
        print_warning "ML setup script not found, skipping..."
    fi
fi

# Step 8: Jupyter
if [[ "$INSTALL_JUPYTER" =~ ^[Yy]$ ]]; then
    print_step "Setting up Jupyter Lab"
    if [[ -f "jupyter/setup_jupyter.sh" ]]; then
        bash jupyter/setup_jupyter.sh
        print_success "Jupyter Lab configured"
    else
        # Fallback installation
        pip install jupyter jupyterlab
        print_success "Jupyter installed via pip"
    fi
fi

# Step 9: Additional Services
print_step "Setting up Additional Services"

# DevPI (Package caching)
if [[ -f "devpi/setup_devpi.sh" ]]; then
    bash devpi/setup_devpi.sh
    print_success "DevPI package cache configured"
fi

# PostgreSQL
if [[ -f "postgres/setup_postgres.sh" ]]; then
    read -p "Install PostgreSQL database? (y/n): " INSTALL_POSTGRES
    if [[ "$INSTALL_POSTGRES" =~ ^[Yy]$ ]]; then
        bash postgres/setup_postgres.sh
        print_success "PostgreSQL configured"
    fi
fi

# Step 10: Kubernetes
if [[ "$INSTALL_K8S" =~ ^[Yy]$ ]]; then
    print_step "Setting up Kubernetes"
    if [[ -f "kubernetes/setup_k8s.sh" ]]; then
        bash kubernetes/setup_k8s.sh
        print_success "Kubernetes configured"
    else
        print_warning "Kubernetes setup script not found, skipping..."
    fi
fi

# Final verification
echo -e "\n${BLUE}=== Final Verification ===${NC}"

echo -e "\n${YELLOW}Testing installations...${NC}"

# Test Python/Conda
if command -v conda >/dev/null 2>&1; then
    echo -e "✅ Conda: $(conda --version)"
else
    echo -e "❌ Conda: Not installed"
fi

# Test Python
if command -v python3 >/dev/null 2>&1; then
    echo -e "✅ Python: $(python3 --version)"
else
    echo -e "❌ Python: Not installed"
fi

# Test Docker
if command -v docker >/dev/null 2>&1; then
    echo -e "✅ Docker: $(docker --version 2>/dev/null || echo 'Installed but daemon not running')"
else
    echo -e "❌ Docker: Not installed"
fi

# Test NVIDIA
if command -v nvidia-smi >/dev/null 2>&1; then
    echo -e "✅ NVIDIA: $(nvidia-smi --query-gpu=name --format=csv,noheader | head -1)"
else
    echo -e "⚠️  NVIDIA: Not installed or not available"
fi

# Test Git
if command -v git >/dev/null 2>&1; then
    echo -e "✅ Git: $(git --version)"
else
    echo -e "❌ Git: Not installed"
fi

# Summary
echo -e "\n${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Setup Complete!             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Next Steps:${NC}"
echo -e "1. ${BLUE}Restart your terminal${NC} (or run: source ~/.bashrc)"
echo -e "2. ${BLUE}Test your setup${NC} with: python3 -c 'import torch; print(torch.cuda.is_available())'"
echo -e "3. ${BLUE}Start Jupyter${NC} with: jupyter lab"
echo -e "4. ${BLUE}Check documentation${NC} in: ./docs/"

echo -e "\n${YELLOW}Configuration files created:${NC}"
echo -e "- Environment variables: .envs.sh"
echo -e "- Jupyter config: jupyter_config.py"
echo -e "- Custom themes: custom/"

echo -e "\n${BLUE}Happy coding! 🚀${NC}" 