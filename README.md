# ML Development Environment Setup

A comprehensive collection of setup scripts, configurations, and tools for building machine learning development environments. This repository provides automated setup for various components commonly used in ML workflows.

## 📚 Quick Start

```bash
# Clone the repository
git clone <your-repo-url>
cd system

# Choose your setup path:
# For complete ML environment:
./setup/complete_setup.sh

# For specific components, see individual sections below
```

## 🏗️ Architecture Overview

This repository provides modular setup for:

- **Development Environment**: Python, Conda, virtual environments
- **ML Infrastructure**: Jupyter, CUDA, PyTorch, vLLM
- **Containerization**: Docker configurations for various services
- **Orchestration**: Kubernetes cluster setup
- **Package Management**: Local PyPI mirrors, caching
- **System Configuration**: Shell, Git, and development tools

## 📂 Repository Structure

```
├── 📁 anaconda/          # Conda environment management
├── 📁 docker/            # Docker configurations & Dockerfiles  
├── 📁 jupyter/           # Jupyter Lab/Notebook setup
├── 📁 jupyter-server/    # Production Jupyter server config
├── 📁 ml/               # Machine Learning tools (CUDA, vLLM, PyTorch)
├── 📁 kubernetes/       # K8s cluster setup and configs
├── 📁 nvidia/           # NVIDIA drivers and CUDA setup
├── 📁 postgres/         # PostgreSQL database setup
├── 📁 devpi/            # Local PyPI server and package caching
├── 📁 setup/            # System setup scripts (Git, shell, etc.)
├── 📁 ubuntu/           # Ubuntu-specific system configuration
├── 📁 mac/              # macOS development setup
├── 📁 zsh/              # Zsh shell configuration
├── 📁 docs/             # Detailed documentation for each component
└── 📄 requirements.txt   # Base Python dependencies
```

## 🚀 Component Documentation

### Core Development Environment

| Component | Purpose | Quick Setup |
|-----------|---------|-------------|
| [**Anaconda**](./docs/anaconda.md) | Python environment management | `./anaconda/install_conda.sh` |
| [**Docker**](./docker/README.md) | Containerization platform | `./docker/install_docker.sh` |
| [**Git Setup**](./docs/git.md) | Version control configuration | `./setup/git.sh` |
| [**Zsh Shell**](./docs/zsh.md) | Enhanced shell with themes | `./zsh/install_zsh.sh` |

### Machine Learning Stack

| Component | Purpose | Quick Setup |
|-----------|---------|-------------|
| [**CUDA & NVIDIA**](./nvidia/README.md) | GPU computing support | `./nvidia/nvidia.sh` |
| [**vLLM**](./docs/vllm.md) | LLM inference engine | `./ml/install_vllm.sh` |
| [**Jupyter**](./docs/jupyter.md) | Interactive notebooks | `./jupyter/install_jupyter.sh` |
| [**PyTorch**](./docs/pytorch.md) | Deep learning framework | Included in ML setup |

### Infrastructure & Services

| Component | Purpose | Quick Setup |
|-----------|---------|-------------|
| [**Kubernetes**](./docs/kubernetes.md) | Container orchestration | `./kubernetes/setup_k8s.sh` |
| [**PostgreSQL**](./postgres/README.md) | Database server | `./postgres/install_postgres.sh` |
| [**DevPI**](./docs/devpi.md) | Local PyPI mirror | `./devpi/setup_devpi.sh` |

### Platform-Specific Setup

| Platform | Purpose | Quick Setup |
|----------|---------|-------------|
| [**Ubuntu**](./docs/ubuntu.md) | Ubuntu system configuration | `./ubuntu/ubuntu_setup.sh` |
| [**macOS**](./docs/macos.md) | macOS development setup | `./mac/mac_dev_setup.sh` |

## 🛠️ Installation Methods

### Method 0: Unified Setup Script (New Ubuntu Machines)
```bash
./setup.sh --role standalone --gpu
./setup.sh --role cluster-master --gpu --enable-kubeflow
./setup.sh --role cluster-worker --master-ip IP --join-token TOKEN --gpu
./setup.sh --profile ml-dev --gpu --dry-run --yes
```

### Method 1: Complete Setup
```bash
# Full ML development environment
./setup/complete_setup.sh
```

### Method 2: Selective Installation
```bash
# Install specific components
./anaconda/install_conda.sh
./nvidia/nvidia.sh  
./ml/install_vllm.sh
```

### Method 3: Docker-based Setup
```bash
# Run pre-configured development environment
docker-compose up -d jupyter-ml
```

## 🔧 Configuration

### Environment Variables
```bash
# Copy and modify environment configuration
cp .envs.example .envs.sh
source .envs.sh
```

### Custom Jupyter Themes
The `jupyter-server/custom/` directory contains shared CSS/JS files for Jupyter customization:
- `custom.css` - Custom styling
- `custom.js` - JavaScript extensions  
- `fonts/` - Custom fonts for notebooks

## 📋 Prerequisites

### Ubuntu/Debian
```bash
sudo apt update && sudo apt install -y curl wget git build-essential
```

### macOS
```bash
# Install Homebrew first
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

## 🧪 Testing Your Setup

```bash
# Test GPU setup
nvidia-smi
python -c "import torch; print(torch.cuda.is_available())"

# Test ML stack
python -c "import vllm; print('vLLM installed successfully')"

# Test Jupyter
jupyter lab --version
```

## 📖 Detailed Documentation

- [**Quick Start Guide**](./docs/quick-start.md) - Get running in minutes
- [**Complete Setup Guide**](./docs/complete-setup.md) - Full environment setup
- [**Component Guides**](./docs/) - Individual component documentation
- [**Troubleshooting**](./docs/troubleshooting.md) - Common issues and solutions
- [**Contributing**](./docs/contributing.md) - How to contribute to this project

## 🚀 Getting Started

**New to this repository?** Start with the [Quick Start Guide](./docs/quick-start.md)

**Need help?** Check the [Troubleshooting Guide](./docs/troubleshooting.md)

**Want to contribute?** See [Contributing Guidelines](./docs/contributing.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

Please read our [Contributing Guidelines](./docs/contributing.md) for detailed information.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 📖 Check the [documentation](./docs/)
- 🐛 [Report bugs](../../issues)
- 💬 [Ask questions](../../discussions)
- 🔧 [Request features](../../issues/new)

---

**Quick Links**: [Setup Guide](./docs/setup.md) | [Components](./docs/) | [Troubleshooting](./docs/troubleshooting.md) | [Contributing](./docs/contributing.md) 