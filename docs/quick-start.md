# Quick Start Guide

Get your ML development environment up and running in minutes.

## 🚀 Choose Your Path

### 🎯 Path 1: Complete ML Environment (Recommended)
**Best for:** New developers setting up a full ML development stack

```bash
# Clone and setup everything
git clone <your-repo-url>
cd system
./setup/complete_setup.sh
```

**What you get:**
- Python environment (Conda)
- GPU support (NVIDIA/CUDA)
- ML frameworks (PyTorch, vLLM)
- Development tools (Jupyter, Docker)
- Package caching (DevPI)

⏱️ **Time:** 15-30 minutes  
💾 **Disk:** ~10GB  

---

### 🐳 Path 2: Docker-First Setup
**Best for:** Consistent environments, CI/CD, team development

```bash
git clone <your-repo-url>
cd system

# Start core services
docker-compose up -d jupyter-ml postgres devpi

# Access Jupyter at http://localhost:8888
# Access DevPI at http://localhost:3141
```

**What you get:**
- Pre-configured containers
- Isolated environments
- Easy scaling and deployment
- Consistent team setups

⏱️ **Time:** 5-10 minutes  
💾 **Disk:** ~5GB  

---

### 🧩 Path 3: Component-by-Component
**Best for:** Existing setups, specific needs, learning

```bash
git clone <your-repo-url>
cd system

# Install base Python environment
./anaconda/install_conda.sh

# Add GPU support (if needed)
./nvidia/nvidia.sh

# Add specific tools
./ml/install_vllm.sh        # For LLM inference
./jupyter/setup_jupyter.sh  # For notebooks
./docker/install_docker.sh  # For containers
```

⏱️ **Time:** Variable  
💾 **Disk:** Variable  

---

## 📋 Prerequisites

### Ubuntu/Debian
```bash
sudo apt update
sudo apt install -y curl wget git build-essential
```

### macOS
```bash
# Install Homebrew (if not already installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git curl wget
```

### Hardware Requirements
- **Minimum:** 8GB RAM, 20GB disk space
- **Recommended:** 16GB RAM, 50GB disk space, NVIDIA GPU
- **For ML/LLM:** 32GB RAM, 100GB disk space, RTX 3080+ GPU

---

## ✅ Verification

### Quick Health Check
```bash
# System info
python --version
conda --version
git --version

# GPU check (if installed)
nvidia-smi
python -c "import torch; print(f'CUDA available: {torch.cuda.is_available()}')"

# Docker check (if installed)
docker --version
docker ps
```

### Component Tests
```bash
# Test ML stack
python ml/test_torch.py
python ml/test_vllm_inference.py

# Test Jupyter
jupyter lab --version
# Access http://localhost:8888

# Test DevPI cache
pip install --index-url http://localhost:3141/root/pypi/+simple/ numpy
```

---

## 🎯 Common Use Cases

### Data Science Workflow
```bash
# Complete setup
./setup/complete_setup.sh

# Start Jupyter
conda activate ml
jupyter lab

# Your data science environment is ready!
```

### LLM Development
```bash
# GPU + ML setup
./nvidia/nvidia.sh
./ml/install_vllm.sh

# Test with a model
python -c "
from vllm import LLM
llm = LLM('microsoft/DialoGPT-medium')
print('LLM ready!')
"
```

### Container Development
```bash
# Docker setup
./docker/install_docker.sh

# Start development stack
docker-compose up -d

# Build your project
docker build -t my-ml-app .
```

### Team Development
```bash
# Setup DevPI for package caching
./devpi/setup_devpi.sh

# Share Jupyter configs
cp -r custom/ ~/.jupyter/custom/

# Use consistent environment
conda env create -f environment.yml
```

---

## 🔧 Customization

### Environment Variables
```bash
# Create your config
cp .env.example .env
nano .env

# Source it
source .env
```

### Custom Configurations
```bash
# Jupyter themes
cp custom/custom.css ~/.jupyter/custom/
cp custom/custom.js ~/.jupyter/custom/

# Conda environments
conda env create -f environments/ml-deep.yml
conda env create -f environments/ml-base.yml
```

---

## 📚 Next Steps

After setup:

1. **Read the documentation**: Check [docs/](../docs/) for detailed guides
2. **Explore examples**: Look at test files and configuration examples
3. **Customize your setup**: Modify configurations for your needs
4. **Join the community**: Check [issues](../../issues) and [discussions](../../discussions)

### Recommended Reading Order
1. [Troubleshooting Guide](troubleshooting.md) - For common issues
2. [Component Documentation](README.md) - For specific tools
3. [Best Practices](best-practices.md) - For optimization tips

---

## 🆘 Need Help?

- **Common issues**: Check [troubleshooting guide](troubleshooting.md)
- **Detailed setup**: See [complete setup guide](complete-setup.md)
- **Component help**: Read individual component docs
- **Community**: [GitHub Issues](../../issues) and [Discussions](../../discussions)

---

**Ready to dive deeper?** Check out the [complete documentation](README.md) or explore specific [component guides](../docs/). 