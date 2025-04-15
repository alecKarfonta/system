#!/bin/bash
# Script to install a compatible version of PyTorch for NVIDIA GeForce RTX 5090

echo "Installing compatible PyTorch version for NVIDIA GeForce RTX 5090..."

# Uninstall current PyTorch
pip uninstall -y torch torchvision torchaudio

# Install the latest PyTorch with CUDA support
# This will install the latest version that should support newer GPUs
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121

# Verify installation
python -c "import torch; print('PyTorch version:', torch.__version__); print('CUDA available:', torch.cuda.is_available()); print('CUDA device count:', torch.cuda.device_count()); print('CUDA device name:', torch.cuda.get_device_name(0) if torch.cuda.is_available() else 'N/A')"

echo "Installation complete. Please run your vLLM test script again." 