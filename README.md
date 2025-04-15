# System Setup and Development Environment Tools

This repository contains a collection of setup scripts and configuration files for setting up a comprehensive machine learning development environment. These tools help automate the installation and configuration of various services and tools commonly used in machine learning workflows.

## Components

### 1. Anaconda Environment
- Python environment management
- Pre-configured with common ML libraries
- Environment isolation for different projects

### 2. Jupyter Server
- Web-based interactive development environment
- Support for notebooks and lab interface
- Remote access capabilities

### 3. NVIDIA Drivers and CUDA
- Latest NVIDIA driver installation
- CUDA toolkit setup
- cuDNN configuration
- GPU monitoring tools

### 4. Kubernetes
- Local Kubernetes cluster setup
- Container orchestration for ML workloads
- Resource management and scaling

### 5. Shell Environment
- Zsh configuration with useful aliases and functions
- Custom prompt and theme
- Development-focused shell utilities

### 6. Package Management
- Pip cache configuration for faster package installation
- Local package repository setup
- Dependency management

## Directory Structure

```
.
├── anaconda/          # Anaconda setup and environment configurations
├── jupyter/          # Jupyter server configuration and setup
├── nvidia/           # NVIDIA drivers and CUDA installation scripts
├── kubernetes/       # Kubernetes cluster setup and configurations
├── shell/            # Zsh configuration and customizations
└── pip/              # Pip cache and package management setup
```

## Usage

Each component has its own setup script and configuration files. To use a specific component:

1. Navigate to the component's directory
2. Review the README.md in that directory for specific instructions
3. Run the setup script as documented

## Requirements

- macOS (tested on macOS 24.1.0)
- Homebrew package manager
- Administrative privileges for system-level installations

## Contributing

Feel free to submit issues and enhancement requests!

## License

This project is licensed under the MIT License - see the LICENSE file for details. 