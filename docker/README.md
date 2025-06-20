# Docker Setup

Docker containerization platform for ML development environments.

## 📋 Overview
Docker provides containerization for consistent, isolated ML development environments. This component sets up Docker Engine, Docker Compose, and optimized configurations for ML workloads including GPU support and development services.

## 🚀 Quick Start
```bash
# Install Docker
./install_docker.sh

# Verify installation
docker --version
docker-compose --version

# Start ML development stack
docker-compose up -d
```

## 📂 Files
- `install_docker.sh` - Docker installation script
- `test_docker.sh` - Docker testing script
- `docker-compose.yml` - Multi-service development stack
- `basic/` - Basic ML container configurations
- `Dockerfile_pytorch_2` - PyTorch 2.x container
- `requirements_notorch.txt` - Non-PyTorch dependencies

## 🛠️ Installation

### Automatic Installation (Recommended)
```bash
./install_docker.sh
```

### Manual Installation Steps

#### Ubuntu/Debian
```bash
# Remove old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Install prerequisites
sudo apt-get update
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common

# Add Docker's official GPG key
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# Add Docker repository
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker Engine
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add user to docker group
sudo usermod -aG docker $USER
newgrp docker
```

#### macOS
```bash
# Install via Homebrew
brew install docker docker-compose

# Or download Docker Desktop
# https://www.docker.com/products/docker-desktop
```

## 🔧 Configuration

### Docker Daemon Configuration
```bash
# Create daemon configuration
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

# Restart Docker
sudo systemctl restart docker
```

### GPU Support (NVIDIA)
```bash
# Install NVIDIA Container Toolkit
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
```

## 🧪 Testing
```bash
# Test Docker installation
./test_docker.sh

# Manual tests
docker run hello-world
docker run --rm -it ubuntu:22.04 echo "Docker works!"

# Test GPU support (if available)
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi
```

## 📚 Usage Examples

### Basic ML Container
```bash
# Build basic ML container
cd basic/
docker build -t ml-basic .

# Run interactive container
docker run --rm -it ml-basic python3
```

### PyTorch Development Container
```bash
# Build PyTorch container
docker build -f Dockerfile_pytorch_2 -t ml-pytorch .

# Run with GPU support
docker run --rm --gpus all -it ml-pytorch python3 -c "import torch; print(torch.cuda.is_available())"
```

### Development Stack
```bash
# Start complete development environment
docker-compose up -d

# Services included:
# - Jupyter Lab (port 8888)
# - PostgreSQL (port 5432)
# - DevPI cache (port 3141)
# - Redis (port 6379)

# Access services
open http://localhost:8888  # Jupyter
open http://localhost:3141  # DevPI
```

### Volume Management
```bash
# Create persistent volumes
docker volume create ml-data
docker volume create ml-models

# Mount volumes
docker run -v ml-data:/data -v ml-models:/models ml-pytorch
```

## 🔍 Troubleshooting

### Issue: Permission denied accessing Docker
**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or logout and login again
```

### Issue: Docker daemon not running
**Solution:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

### Issue: GPU not accessible in containers
**Solution:**
```bash
# Check NVIDIA Container Toolkit installation
nvidia-ctk --version

# Test GPU access
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi

# Reinstall if needed
sudo apt-get install --reinstall nvidia-container-toolkit
sudo systemctl restart docker
```

### Issue: Out of disk space
**Solution:**
```bash
# Clean up Docker resources
docker system prune -a
docker volume prune
docker image prune -a

# Check disk usage
docker system df
```

### Issue: Port conflicts
**Solution:**
```bash
# Check what's using ports
sudo netstat -tulpn | grep :8888

# Stop conflicting services
sudo systemctl stop jupyter
# Or use different ports in docker-compose.yml
```

## 📖 Advanced Usage

### Multi-stage Builds
```dockerfile
# Example multi-stage Dockerfile
FROM python:3.10-slim as builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --user -r requirements.txt

FROM python:3.10-slim
WORKDIR /app
COPY --from=builder /root/.local /root/.local
COPY . .
ENV PATH=/root/.local/bin:$PATH
CMD ["python", "app.py"]
```

### Docker Compose Override
```yaml
# docker-compose.override.yml
version: '3.8'
services:
  jupyter:
    volumes:
      - ./notebooks:/home/jovyan/work
    environment:
      - JUPYTER_TOKEN=your-token
  
  postgres:
    environment:
      - POSTGRES_PASSWORD=your-password
```

### Health Checks
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8888/api || exit 1
```

## 📖 Additional Resources
- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Reference](https://docs.docker.com/compose/)
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker)
- [Docker Best Practices](https://docs.docker.com/develop/best-practices/)

---
**Next Steps**: After Docker setup, consider setting up [Jupyter](../jupyter/) or [Kubernetes](../kubernetes/) for development workflows. 