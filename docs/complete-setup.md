# Complete ML Development Environment Setup Guide

This comprehensive guide walks you through setting up a complete machine learning development environment from scratch.

## 📋 Overview

By the end of this guide, you'll have:
- **Python Environment**: Conda with optimized ML environments
- **GPU Support**: NVIDIA drivers and CUDA toolkit
- **ML Frameworks**: PyTorch, vLLM, and related tools
- **Development Tools**: Jupyter Lab, Docker, Git
- **Infrastructure**: Package caching, database, container orchestration
- **Shell Enhancement**: Zsh with productivity features

**Total Time**: 30-60 minutes (depending on internet speed and hardware)
**Disk Space**: ~15-20GB

## 🖥️ System Requirements

### Minimum Requirements
- **OS**: Ubuntu 20.04+ or macOS 11+
- **RAM**: 8GB (16GB recommended for ML workloads)
- **Storage**: 20GB free space (50GB recommended)
- **Network**: Stable internet connection

### Recommended Requirements
- **OS**: Ubuntu 22.04 LTS or macOS 13+
- **RAM**: 32GB (for large models)
- **Storage**: 100GB+ SSD
- **GPU**: NVIDIA RTX 3080+ with 12GB+ VRAM
- **Network**: Fast connection for package downloads

## 🚀 Pre-Installation Checklist

### Before You Begin
- [ ] Back up important data
- [ ] Ensure stable power supply (for laptops, connect charger)
- [ ] Close unnecessary applications to free up resources
- [ ] Have administrator/sudo access
- [ ] Review system requirements above

### System Updates
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# macOS
sudo softwareupdate -i -a
```

## 📦 Installation Methods

Choose the method that best fits your needs:

### Method 1: Automated Complete Setup (Recommended)
**Best for**: New users, clean installations

```bash
# Clone repository
git clone <your-repo-url>
cd system

# Run complete setup (interactive)
./setup/complete_setup.sh
```

### Method 2: Docker-First Setup
**Best for**: Team environments, CI/CD, quick testing

```bash
# Clone repository
git clone <your-repo-url>
cd system

# Start with Docker services
docker-compose up -d
```

### Method 3: Manual Step-by-Step
**Best for**: Learning, custom installations, existing setups

Follow the detailed steps below.

---

## 🔧 Manual Step-by-Step Installation

### Step 1: System Prerequisites

#### Ubuntu/Debian
```bash
# Update package lists
sudo apt update

# Install essential tools
sudo apt install -y \
    curl \
    wget \
    git \
    build-essential \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Install additional utilities
sudo apt install -y \
    htop \
    tree \
    unzip \
    vim \
    tmux
```

#### macOS
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install essential tools
brew install git curl wget tree htop vim tmux

# Install Xcode command line tools
xcode-select --install
```

### Step 2: Git Configuration
```bash
# Run git setup script
./setup/git.sh

# Or configure manually
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
git config --global init.defaultBranch main
```

### Step 3: Python Environment (Conda)
```bash
# Install Conda
./anaconda/install_conda.sh

# Reload shell to get conda command
source ~/.bashrc  # or source ~/.zshrc for zsh

# Verify installation
conda --version
conda info

# Create base ML environment
conda create -n ml python=3.10 -y
conda activate ml
```

### Step 4: NVIDIA Drivers and CUDA (GPU Systems Only)
```bash
# Check if NVIDIA GPU is present
lspci | grep -i nvidia

# If GPU found, install drivers
./nvidia/nvidia.sh

# Reboot system
sudo reboot

# After reboot, verify installation
nvidia-smi
nvcc --version
```

### Step 5: Docker Installation
```bash
# Ubuntu - Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker

# macOS - Install Docker Desktop
brew install --cask docker

# Verify installation
docker --version
docker-compose --version
```

### Step 6: Machine Learning Stack
```bash
# Activate ML environment
conda activate ml

# Install PyTorch with CUDA support (if GPU available)
# For CUDA 11.8
conda install pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia

# For CPU only
conda install pytorch torchvision torchaudio cpuonly -c pytorch

# Install vLLM
./ml/install_vllm.sh

# Verify PyTorch
python -c "import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA available: {torch.cuda.is_available()}')"
```

### Step 7: Jupyter Lab Setup
```bash
# Install Jupyter in ML environment
conda activate ml
conda install -c conda-forge jupyterlab ipykernel

# Install additional Jupyter extensions
pip install jupyterlab-git jupyterlab-lsp

# Configure Jupyter
jupyter lab --generate-config

# Install custom themes (optional)
cp -r custom/ ~/.jupyter/custom/

# Create kernel for ML environment
python -m ipykernel install --user --name ml --display-name "Python (ML)"

# Test Jupyter
jupyter lab --version
```

### Step 8: Development Services

#### DevPI Package Cache
```bash
# Install and configure DevPI
pip install devpi-server devpi-web

# Initialize and start server
devpi-init
devpi-server --start --host 0.0.0.0 --port 3141

# Configure as systemd service (Linux)
sudo cp devpi/devpi.service /etc/systemd/system/
sudo systemctl enable devpi
sudo systemctl start devpi
```

#### PostgreSQL Database (Optional)
```bash
# Ubuntu
sudo apt install -y postgresql postgresql-contrib

# macOS
brew install postgresql
brew services start postgresql

# Create development database
sudo -u postgres createdb ml_dev
```

### Step 9: Shell Enhancement (Optional)
```bash
# Install Zsh
sudo apt install zsh  # Ubuntu
brew install zsh      # macOS

# Install Oh My Zsh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"

# Set as default shell
chsh -s $(which zsh)
```

### Step 10: Kubernetes Setup (Optional)
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl

# Install microk8s (Ubuntu)
sudo snap install microk8s --classic
sudo usermod -a -G microk8s $USER
newgrp microk8s

# Enable basic add-ons
microk8s enable dns dashboard ingress
```

---

## ✅ Verification and Testing

### System Health Check
```bash
# Basic system info
echo "=== System Information ==="
uname -a
cat /etc/os-release  # Linux only

echo "=== Memory and Disk ==="
free -h
df -h

echo "=== GPU Information ==="
nvidia-smi  # If GPU available
```

### Python Environment Check
```bash
# Activate environment
conda activate ml

echo "=== Python Environment ==="
python --version
pip --version
conda --version

echo "=== ML Libraries ==="
python -c "import torch; print(f'PyTorch: {torch.__version__}')"
python -c "import torch; print(f'CUDA: {torch.cuda.is_available()}')"
python -c "import vllm; print('vLLM: OK')"
```

### Service Check
```bash
echo "=== Services ==="
docker --version
jupyter --version
git --version

# Check running services
docker ps
sudo systemctl status devpi  # If installed as service
```

### Functional Tests
```bash
# Test ML stack
python ml/test_torch.py
python ml/test_vllm_inference.py

# Test Jupyter (start in background)
jupyter lab --no-browser --port=8888 &
sleep 5
curl -f http://localhost:8888/lab || echo "Jupyter not accessible"
pkill -f "jupyter-lab"  # Stop test instance

# Test Docker
docker run hello-world
```

---

## 🎯 Post-Installation Configuration

### Environment Variables
Create a configuration file for your environment:

```bash
# Create .envrc file
cat > .envrc << 'EOF'
# Python/Conda
export PATH="$HOME/miniconda3/bin:$PATH"

# CUDA (if installed)
export CUDA_HOME=/usr/local/cuda
export PATH="$CUDA_HOME/bin:$PATH"
export LD_LIBRARY_PATH="$CUDA_HOME/lib64:$LD_LIBRARY_PATH"

# ML Development
export PYTHONPATH="$PWD:$PYTHONPATH"
export ML_ENV_NAME="ml"

# DevPI Cache
export PIP_INDEX_URL="http://localhost:3141/root/pypi/+simple/"
export PIP_TRUSTED_HOST="localhost"
EOF

# Source it
source .envrc
```

### Conda Environment Templates
```bash
# Create environment templates
mkdir -p environments

# Base ML environment
cat > environments/ml-base.yml << 'EOF'
name: ml-base
channels:
  - conda-forge
  - pytorch
  - nvidia
dependencies:
  - python=3.10
  - jupyter
  - pandas
  - numpy
  - matplotlib
  - scikit-learn
  - pytorch
  - torchvision
  - torchaudio
  - pytorch-cuda=11.8
  - pip
  - pip:
    - vllm
    - transformers
    - datasets
EOF

# Deep Learning environment
cat > environments/ml-deep.yml << 'EOF'
name: ml-deep
channels:
  - conda-forge
  - pytorch
  - nvidia
  - huggingface
dependencies:
  - python=3.10
  - jupyter
  - pytorch
  - torchvision
  - torchaudio
  - pytorch-cuda=11.8
  - transformers
  - datasets
  - accelerate
  - tensorboard
  - pip
  - pip:
    - vllm
    - flash-attn
    - bitsandbytes
EOF
```

### Docker Services Configuration
```bash
# Start development services
docker-compose up -d jupyter postgres devpi

# Configure for auto-start
docker-compose -f docker-compose.yml -f docker-compose.prod.yml up -d
```

---

## 🔍 Troubleshooting Common Issues

### CUDA Issues
```bash
# Check CUDA installation
nvidia-smi
nvcc --version

# Reinstall if version mismatch
sudo apt remove --purge nvidia-*
sudo apt autoremove
./nvidia/nvidia.sh
```

### Python/Conda Issues
```bash
# Reset conda if corrupted
conda clean --all
conda update conda

# Recreate environment
conda env remove -n ml
conda env create -f environments/ml-base.yml
```

### Docker Permission Issues
```bash
# Fix Docker permissions
sudo usermod -aG docker $USER
newgrp docker
# Or logout/login
```

### Service Issues
```bash
# Restart all services
sudo systemctl restart devpi
docker-compose restart
```

For more detailed troubleshooting, see the [Troubleshooting Guide](troubleshooting.md).

---

## 🚀 Next Steps

### Immediate Next Steps
1. **Test your setup** with the provided test scripts
2. **Explore Jupyter Lab** at http://localhost:8888
3. **Try a simple ML workflow** using the installed tools
4. **Customize your environment** based on your needs

### Learning Resources
- [Component Documentation](README.md) - Detailed guides for each tool
- [Best Practices](best-practices.md) - Optimization tips
- [Example Projects](examples/) - Sample ML projects

### Community
- [GitHub Issues](../../issues) - Report problems or ask questions
- [Discussions](../../discussions) - Community support and ideas
- [Contributing](contributing.md) - Help improve this project

---

## 📊 What You've Accomplished

🎉 **Congratulations!** You now have a complete ML development environment with:

- ✅ **Python Development**: Conda with optimized environments
- ✅ **GPU Computing**: NVIDIA drivers and CUDA support
- ✅ **ML Frameworks**: PyTorch and vLLM for model development
- ✅ **Development Tools**: Jupyter Lab for interactive development
- ✅ **Infrastructure**: Docker for containerization
- ✅ **Performance**: Package caching for faster installs
- ✅ **Productivity**: Enhanced shell and development tools

**Total Installation Size**: ~15-20GB
**Ready for**: Data science, machine learning, LLM development, research

---

**Need help?** Check the [troubleshooting guide](troubleshooting.md) or [create an issue](../../issues/new). 