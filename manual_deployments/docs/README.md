# Documentation Index

This directory contains detailed documentation for each component of the ML Development Environment Setup.

## 📚 Component Documentation

### Core Development Environment
- [**Anaconda Setup**](./anaconda.md) - Python environment management with Conda
- [**Docker Configuration**](./docker.md) - Container setup and management  
- [**Git Configuration**](./git.md) - Version control setup and aliases
- [**Zsh Shell Setup**](./zsh.md) - Enhanced shell with Oh My Zsh and themes

### Machine Learning Stack
- [**NVIDIA & CUDA Setup**](./nvidia.md) - GPU drivers and CUDA toolkit installation
- [**vLLM Installation**](./vllm.md) - Large Language Model inference engine
- [**Jupyter Configuration**](./jupyter.md) - Interactive notebook environments
- [**PyTorch Setup**](./pytorch.md) - Deep learning framework installation

### Infrastructure Services
- [**Kubernetes Setup**](./kubernetes.md) - Container orchestration platform
- [**PostgreSQL Configuration**](./postgres.md) - Database server setup
- [**DevPI Server**](./devpi.md) - Local PyPI package mirror and caching

### Platform-Specific Guides
- [**Ubuntu System Setup**](./ubuntu.md) - Ubuntu-specific configurations
- [**macOS Development Setup**](./macos.md) - macOS development environment

### Advanced Topics
- [**Complete Setup Guide**](./complete-setup.md) - Full environment installation
- [**Docker Compose Services**](./docker-compose.md) - Multi-service containerization
- [**Custom Jupyter Themes**](./jupyter-themes.md) - Styling and customization
- [**Troubleshooting Guide**](./troubleshooting.md) - Common issues and solutions

## 🚀 Quick Start Guides

### New Developer Setup
1. [**Ubuntu New System**](./ubuntu.md#new-system-setup)
2. [**macOS New System**](./macos.md#new-system-setup)
3. [**Complete ML Environment**](./complete-setup.md)

### Component-Specific Setup
- **Just Jupyter**: Follow [Jupyter Guide](./jupyter.md)
- **Just ML Tools**: Follow [vLLM Guide](./vllm.md) + [NVIDIA Guide](./nvidia.md)
- **Just Docker**: Follow [Docker Guide](./docker.md)

## 📖 Documentation Standards

Each component documentation includes:
- **Purpose** - What the component does
- **Prerequisites** - What you need before installation
- **Installation** - Step-by-step setup instructions
- **Configuration** - How to customize the setup
- **Testing** - How to verify the installation works
- **Troubleshooting** - Common issues and solutions

## 🤝 Contributing to Documentation

When adding new components or updating existing ones:

1. **Follow the template** in `template.md`
2. **Include examples** for all major use cases
3. **Test all commands** before documenting them
4. **Update the main README** to reference your new docs
5. **Add troubleshooting section** for common issues

## 📂 File Naming Convention

- `component-name.md` - Main component documentation
- `component-name-advanced.md` - Advanced configuration
- `component-name-troubleshooting.md` - Specific troubleshooting (if extensive)

---

**Need help?** Check the [troubleshooting guide](./troubleshooting.md) or [open an issue](../../issues). 