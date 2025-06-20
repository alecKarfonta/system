# Troubleshooting Guide

Common issues and solutions for ML development environment setup.

## 🚨 Quick Fixes

### Permission Issues
```bash
# Fix common permission problems
sudo chown -R $USER:$USER ~/.local
sudo usermod -aG docker $USER
newgrp docker
```

### Path Issues
```bash
# Add common paths
export PATH="$HOME/miniconda3/bin:$PATH"
export PATH="/usr/local/cuda/bin:$PATH"
source ~/.bashrc
```

## 🔧 Component-Specific Issues

### CUDA/NVIDIA Issues

#### Issue: `nvidia-smi` command not found
**Solution:**
```bash
# Check driver installation
lspci | grep -i nvidia
sudo apt install nvidia-driver-525
sudo reboot
```

#### Issue: CUDA version mismatch
**Solution:**
```bash
# Check CUDA version
nvcc --version
nvidia-smi  # Check driver version

# Install matching CUDA toolkit
sudo apt install cuda-toolkit-11-8
```

#### Issue: PyTorch not detecting GPU
**Solution:**
```bash
python -c "import torch; print(torch.cuda.is_available())"
python -c "import torch; print(torch.version.cuda)"

# Reinstall PyTorch with correct CUDA version
pip uninstall torch torchvision torchaudio
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
```

### Docker Issues

#### Issue: Permission denied accessing Docker
**Solution:**
```bash
sudo usermod -aG docker $USER
newgrp docker
# Or restart session
```

#### Issue: Docker daemon not running
**Solution:**
```bash
sudo systemctl start docker
sudo systemctl enable docker
```

#### Issue: Docker builds failing
**Solution:**
```bash
# Clean Docker cache
docker system prune -a
docker builder prune

# Check disk space
df -h
```

### Conda Issues

#### Issue: Conda command not found
**Solution:**
```bash
# Add conda to PATH
echo 'export PATH="$HOME/miniconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or reinstall
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
bash Miniconda3-latest-Linux-x86_64.sh
```

#### Issue: Environment conflicts
**Solution:**
```bash
# Create clean environment
conda deactivate
conda env remove -n problematic_env
conda clean --all
conda create -n new_env python=3.10
```

### vLLM Issues

#### Issue: Out of memory errors
**Solution:**
```bash
# Use smaller model or reduce batch size
export CUDA_VISIBLE_DEVICES=0  # Use single GPU
# Or enable model quantization in code
```

#### Issue: Installation fails
**Solution:**
```bash
# Install with verbose output
pip install vllm -v

# Install dependencies separately
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu118
pip install vllm --no-deps
```

### Jupyter Issues

#### Issue: Jupyter not starting
**Solution:**
```bash
# Reset Jupyter configuration
jupyter --config-dir
rm -rf ~/.jupyter
jupyter notebook --generate-config
```

#### Issue: Kernel not found
**Solution:**
```bash
# Install kernel for environment
conda activate your_env
pip install ipykernel
python -m ipykernel install --user --name your_env
```

## 🔍 Diagnostic Commands

### System Information
```bash
# OS Information
cat /etc/os-release
uname -a

# Hardware Information
lscpu
free -h
df -h
lspci | grep -i nvidia
```

### Python Environment
```bash
# Python and pip versions
python --version
pip --version
which python
which pip

# Installed packages
pip list
conda list
```

### GPU Information
```bash
# NVIDIA Information
nvidia-smi
nvcc --version
nvidia-settings --query all

# CUDA Installation
ls /usr/local/cuda*
echo $CUDA_HOME
echo $PATH | grep cuda
```

### Docker Status
```bash
# Docker Information
docker --version
docker-compose --version
docker info
docker ps -a
```

## 🐛 Advanced Troubleshooting

### Log Files to Check
```bash
# System logs
sudo journalctl -f
sudo dmesg | tail -20

# Docker logs
docker logs container_name

# Conda logs
conda info -s

# NVIDIA logs
sudo journalctl -u nvidia-persistenced
```

### Clean Installation
If all else fails, clean installation:
```bash
# Remove all components
./cleanup.sh  # If available

# Or manual cleanup
pip uninstall -y $(pip freeze | cut -d'=' -f1)
conda env remove --name your_env
docker system prune -a
sudo apt remove --purge nvidia-*
sudo apt autoremove

# Restart and run setup again
sudo reboot
./setup/complete_setup.sh
```

## 📞 Getting Help

### Before Asking for Help
1. Check this troubleshooting guide
2. Search existing [GitHub issues](../../issues)
3. Run diagnostic commands above
4. Collect relevant log files

### When Reporting Issues
Include:
- OS version and architecture
- Component versions (Python, CUDA, Docker, etc.)
- Complete error message
- Steps to reproduce
- Output of diagnostic commands

### Community Resources
- [Project Issues](../../issues)
- [Discussions](../../discussions)
- Component-specific documentation
- Official project documentation

---

**Can't find your issue?** [Open a new issue](../../issues/new) with detailed information. 