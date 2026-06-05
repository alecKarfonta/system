# Anaconda/Conda Setup

Python environment management with Anaconda/Miniconda for ML development.

## 📋 Overview

This component provides automated installation and configuration of Anaconda/Miniconda, which is essential for:
- Python package management
- Virtual environment isolation
- Reproducible ML environments
- Easy switching between Python versions

## 🚀 Quick Start

```bash
# Install Miniconda
./install_conda.sh

# Verify installation
conda --version
conda info
```

## 📂 Files

- `install_conda.sh` - Main installation script
- `conda_venvs.md` - Virtual environment management guide

## 🛠️ Installation

### Automatic Installation
```bash
./install_conda.sh
```

### Manual Installation Steps
1. **Download Miniconda**:
   ```bash
   wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
   ```

2. **Install**:
   ```bash
   chmod +x Miniconda3-latest-Linux-x86_64.sh
   ./Miniconda3-latest-Linux-x86_64.sh
   ```

3. **Configure PATH**:
   ```bash
   source ~/miniconda3/bin/activate
   export PATH="/home/$USER/miniconda3/bin:$PATH"
   ```

## 🔧 Configuration

### Create ML Environment
```bash
# Create base ML environment
conda create -n ml python=3.10
conda activate ml

# Install common packages
conda install jupyter pandas numpy scipy matplotlib seaborn scikit-learn
conda install pytorch torchvision torchaudio pytorch-cuda=11.8 -c pytorch -c nvidia
```

### Environment Management
```bash
# List environments
conda env list

# Create environment from file
conda env create -f environment.yml

# Export environment
conda env export > environment.yml

# Remove environment
conda env remove -n myenv
```

## 📖 Common Environments

### Base ML Environment
```yaml
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
```

### Deep Learning Environment
```yaml
name: ml-deep
channels:
  - conda-forge
  - pytorch
  - nvidia
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
```

## 🧪 Testing

```bash
# Test conda installation
conda --version
conda info

# Test environment creation
conda create -n test python=3.10
conda activate test
python --version
conda deactivate
conda env remove -n test
```

## 🔍 Troubleshooting

### Issue: Command 'conda' not found
```bash
# Add conda to PATH
export PATH="/home/$USER/miniconda3/bin:$PATH"
echo 'export PATH="/home/$USER/miniconda3/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

### Issue: SSL Certificate errors
```bash
# Update certificates
conda config --set ssl_verify false
# Or update ca-certificates
conda update ca-certificates
```

### Issue: Slow package installation
```bash
# Use faster channels
conda config --add channels conda-forge
conda config --set channel_priority strict
```

## 📚 Additional Resources

- [Conda Documentation](https://docs.conda.io/)
- [Conda Cheat Sheet](https://docs.conda.io/projects/conda/en/4.6.0/_downloads/52a95608c49671267e40c689e0bc00ca/conda-cheatsheet.pdf)
- [Managing Environments](https://docs.conda.io/projects/conda/en/latest/user-guide/tasks/manage-environments.html)

---

**Next Steps**: After conda setup, consider installing [Docker](../docker/) or [Jupyter](../jupyter/) components. 