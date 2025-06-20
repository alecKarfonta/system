# NVIDIA/CUDA Setup

NVIDIA drivers and CUDA toolkit for GPU-accelerated machine learning.

## 📋 Overview
This component installs NVIDIA drivers, CUDA toolkit, and related GPU computing libraries required for ML frameworks like PyTorch and vLLM. Essential for GPU-accelerated training and inference.

## 🚀 Quick Start
```bash
# Install NVIDIA drivers and CUDA
./nvidia.sh

# Verify installation
nvidia-smi
nvcc --version
```

## 📂 Files
- `nvidia.sh` - Main NVIDIA/CUDA installation script
- `nvidia-docker.sh` - Docker GPU support setup
- `docker-compose.yml` - GPU-enabled container services

## 🛠️ Installation

### Automatic Installation (Recommended)
```bash
./nvidia.sh
```

### Manual Installation Steps

#### Check GPU Compatibility
```bash
# Check if NVIDIA GPU is present
lspci | grep -i nvidia

# Check current driver (if any)
nvidia-smi 2>/dev/null || echo "No NVIDIA driver found"
```

#### Ubuntu/Debian Installation
```bash
# Update package lists
sudo apt update

# Install prerequisites
sudo apt install -y software-properties-common

# Add NVIDIA package repository
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.0-1_all.deb
sudo dpkg -i cuda-keyring_1.0-1_all.deb
sudo apt update

# Install NVIDIA driver
sudo apt install -y nvidia-driver-535

# Install CUDA toolkit
sudo apt install -y cuda-toolkit-11-8

# Install cuDNN (optional but recommended)
sudo apt install -y libcudnn8 libcudnn8-dev

# Reboot system
sudo reboot
```

#### Alternative: Ubuntu PPA Method
```bash
# Add graphics-drivers PPA
sudo add-apt-repository ppa:graphics-drivers/ppa
sudo apt update

# Install latest driver
sudo apt install -y nvidia-driver-535

# Install CUDA via runfile
wget https://developer.download.nvidia.com/compute/cuda/11.8.0/local_installers/cuda_11.8.0_520.61.05_linux.run
sudo sh cuda_11.8.0_520.61.05_linux.run --toolkit --silent --override
```

## 🔧 Configuration

### Environment Variables
```bash
# Add to ~/.bashrc or ~/.zshrc
export CUDA_HOME=/usr/local/cuda
export PATH=$CUDA_HOME/bin:$PATH
export LD_LIBRARY_PATH=$CUDA_HOME/lib64:$LD_LIBRARY_PATH

# For PyTorch
export TORCH_CUDA_ARCH_LIST="6.0;6.1;7.0;7.5;8.0;8.6"

# Source the changes
source ~/.bashrc
```

### CUDA Runtime Configuration
```bash
# Set GPU memory growth (optional)
export TF_FORCE_GPU_ALLOW_GROWTH=true

# Set CUDA visible devices
export CUDA_VISIBLE_DEVICES=0,1,2,3  # Use specific GPUs
# export CUDA_VISIBLE_DEVICES=""     # Disable GPU
```

### Power Management
```bash
# Enable persistence mode (recommended for servers)
sudo nvidia-smi -pm 1

# Set power limit (adjust for your GPU)
sudo nvidia-smi -pl 300  # 300W limit

# Set application clocks
sudo nvidia-smi -ac 1215,1410  # Memory,Graphics clocks
```

## 🧪 Testing
```bash
# Test NVIDIA driver
nvidia-smi

# Test CUDA installation
nvcc --version
nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv

# Test CUDA samples (if installed)
cd /usr/local/cuda/samples/1_Utilities/deviceQuery
sudo make
./deviceQuery

# Test with Python
python3 -c "
import torch
print(f'PyTorch version: {torch.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
print(f'CUDA version: {torch.version.cuda}')
print(f'GPU count: {torch.cuda.device_count()}')
if torch.cuda.is_available():
    print(f'GPU name: {torch.cuda.get_device_name(0)}')
"
```

## 📚 Usage Examples

### Basic GPU Information
```bash
# Detailed GPU information
nvidia-smi -L  # List GPUs
nvidia-smi -q  # Detailed query

# Monitor GPU usage
nvidia-smi -l 1  # Update every second
watch -n 1 nvidia-smi
```

### CUDA Memory Management
```python
import torch

# Check CUDA memory
print(f"Total memory: {torch.cuda.get_device_properties(0).total_memory / 1e9:.2f} GB")
print(f"Reserved memory: {torch.cuda.memory_reserved(0) / 1e9:.2f} GB")
print(f"Allocated memory: {torch.cuda.memory_allocated(0) / 1e9:.2f} GB")

# Clear cache
torch.cuda.empty_cache()
```

### Multi-GPU Setup
```python
import torch

# Check available GPUs
if torch.cuda.device_count() > 1:
    print(f"Using {torch.cuda.device_count()} GPUs")
    
    # DataParallel example
    model = torch.nn.DataParallel(model)
    
    # Or specify devices
    device_ids = [0, 1, 2, 3]
    model = torch.nn.DataParallel(model, device_ids=device_ids)
```

## 🔍 Troubleshooting

### Issue: `nvidia-smi` command not found
**Solution:**
```bash
# Check if driver is installed
lsmod | grep nvidia

# Reinstall driver
sudo apt purge nvidia-*
sudo apt autoremove
sudo apt install nvidia-driver-535
sudo reboot
```

### Issue: CUDA version mismatch
**Solution:**
```bash
# Check versions
nvidia-smi  # Driver version
nvcc --version  # CUDA compiler version

# They can be different - nvidia-smi shows max supported CUDA version
# Install matching PyTorch version:
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### Issue: Out of memory errors
**Solution:**
```bash
# Monitor GPU memory
nvidia-smi

# Python memory debugging
import torch
torch.cuda.memory_summary()

# Reduce batch size or model size
# Enable gradient checkpointing
# Use mixed precision training
```

### Issue: Driver installation fails
**Solution:**
```bash
# Disable nouveau driver
echo 'blacklist nouveau' | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
echo 'options nouveau modeset=0' | sudo tee -a /etc/modprobe.d/blacklist-nouveau.conf
sudo update-initramfs -u
sudo reboot

# Try alternative installation
sudo ubuntu-drivers autoinstall
```

### Issue: CUDA installation conflicts
**Solution:**
```bash
# Clean installation
sudo apt purge nvidia-* cuda-*
sudo apt autoremove
sudo apt autoclean

# Remove CUDA directories
sudo rm -rf /usr/local/cuda*

# Reinstall
./nvidia.sh
```

## 📖 Advanced Configuration

### Multiple CUDA Versions
```bash
# Install multiple CUDA versions
sudo apt install cuda-toolkit-11-7 cuda-toolkit-11-8

# Switch between versions
export CUDA_HOME=/usr/local/cuda-11.7
# or
export CUDA_HOME=/usr/local/cuda-11.8

# Update symlink
sudo rm /usr/local/cuda
sudo ln -s /usr/local/cuda-11.8 /usr/local/cuda
```

### Performance Tuning
```bash
# Set persistence mode
sudo nvidia-smi -pm 1

# Set compute mode (exclusive process)
sudo nvidia-smi -c 3

# Max performance mode
sudo nvidia-smi -q -d PERFORMANCE

# Custom fan curves (some GPUs)
sudo nvidia-settings -a [gpu:0]/GPUFanControlState=1
sudo nvidia-settings -a [fan:0]/GPUTargetFanSpeed=75
```

### Container GPU Support
```bash
# Install NVIDIA Container Toolkit
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

curl -s -L https://nvidia.github.io/libnvidia-container/$distribution/libnvidia-container.repo | \
    sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
    sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configure Docker
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker

# Test GPU in container
docker run --rm --gpus all nvidia/cuda:11.8-base-ubuntu22.04 nvidia-smi
```

## 📊 Monitoring and Diagnostics

### Real-time Monitoring
```bash
# Basic monitoring
watch -n 1 nvidia-smi

# Detailed monitoring
nvidia-smi dmon  # Device monitoring
nvidia-smi pmon  # Process monitoring

# Temperature monitoring
nvidia-smi --query-gpu=temperature.gpu --format=csv -l 1
```

### Log Analysis
```bash
# Check system logs
sudo journalctl -u nvidia-persistenced
dmesg | grep -i nvidia

# Check CUDA installation log
cat /var/log/cuda-installer.log

# Check driver installation
cat /var/log/nvidia-installer.log
```

## 📖 Additional Resources
- [NVIDIA Developer Documentation](https://developer.nvidia.com/cuda-toolkit)
- [CUDA Installation Guide](https://docs.nvidia.com/cuda/cuda-installation-guide-linux/)
- [PyTorch CUDA Support](https://pytorch.org/get-started/locally/)
- [NVIDIA Container Toolkit](https://github.com/NVIDIA/nvidia-docker)

---
**Next Steps**: After NVIDIA setup, install [PyTorch](../ml/) or [vLLM](../ml/) for GPU-accelerated ML development. 