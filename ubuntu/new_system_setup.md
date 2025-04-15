# Ubuntu System Setup Guide

This guide will help you set up a new Ubuntu system with essential configurations and tools.

## Initial System Setup

### 1. Update System Packages
First, update your system packages to ensure you have the latest versions:
```bash
sudo apt update
sudo apt upgrade -y
```

### 2. Install and Configure ZSH
ZSH (Z Shell) is a powerful shell that offers better features than the default bash shell:

```bash
# Install ZSH
sudo apt install zsh

# Verify installation
zsh --version

# Set ZSH as default shell
chsh -s $(which zsh)

# Log out and log back in for changes to take effect
exit
```

### 3. Install Essential Tools
Install commonly used development tools and utilities:
```bash
# Install build essentials and git
sudo apt install -y build-essential git curl wget

# Install system utilities
sudo apt install -y btop tmux vim
```

### 4. Install NVIDIA Drivers (if needed)
If you have an NVIDIA graphics card, follow these steps to install the proper drivers:

```bash
# Install required packages
sudo apt install -y dkms gcc make libglvnd-dev pkg-config

# Blacklist Nouveau driver
sudo bash -c "echo blacklist nouveau > /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo bash -c "echo options nouveau modeset=0 >> /etc/modprobe.d/blacklist-nvidia-nouveau.conf"
sudo update-initramfs -u

# Switch to text mode for clean installation
sudo systemctl set-default multi-user.target
sudo reboot
```

### 5. Install CUDA (if needed)
If you need CUDA for GPU acceleration, follow these steps:

```bash
# Download and install CUDA repository key
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb
sudo dpkg -i cuda-keyring_1.1-1_all.deb

# Update package list and install CUDA
sudo apt-get update
sudo apt-get -y install cuda

# Verify CUDA installation
ls -la /usr/local/cuda* 2>/dev/null || echo "No CUDA directory found"
nvidia-smi
nvcc --version
```

### 6. Configure Git
Set up your Git configuration:
```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

## Additional Setup (Optional)

### 1. Configure Sudo Timeout
To set a longer timeout for sudo password prompts:
```bash
sudo sh -c 'echo "Defaults timestamp_timeout=30000" >> /etc/sudoers.d/timeout'
```

### 2. Install Development Tools
```bash
# Install Python and pip
sudo apt install -y python3 python3-pip

# Install Node.js and npm
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
```

### 3. Install Docker
```bash
# Remove any old versions
sudo apt-get remove docker docker-engine docker.io containerd runc

# Update the package index
sudo apt update

# Install prerequisites
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common gnupg lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up the repository with correct Ubuntu codename
UBUNTU_CODENAME=$(lsb_release -cs)
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Update apt package index with the new repository
sudo apt update

# Install Docker Engine and related tools
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Add your user to docker group
sudo usermod -aG docker $USER

# Start and enable Docker service
sudo systemctl start docker
sudo systemctl enable docker
```

### 4. Install NVIDIA Container Toolkit (if needed)
If you have an NVIDIA GPU and want to use it with Docker containers:

```bash
# Set up the NVIDIA Container Toolkit repository

curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
&& curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

# Install the NVIDIA Container Toolkit
sudo apt update
sudo apt install -y nvidia-container-toolkit

# Configure Docker to use NVIDIA runtime
sudo nvidia-ctk runtime configure --runtime=docker
sudo systemctl restart docker
```

## Security Recommendations

1. Configure UFW (Uncomplicated Firewall):
```bash
sudo apt install ufw
sudo ufw enable
sudo ufw allow ssh
```

2. Set up automatic security updates:
```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure unattended-upgrades
```

## Notes
- After making changes to groups (like docker), you'll need to log out and back in for them to take effect
- Keep your system updated regularly using `sudo apt update && sudo apt upgrade`
- Consider setting up a backup solution for important data

## Troubleshooting
If you encounter any issues:
1. Check system logs: `journalctl -xe`
2. Verify service status: `systemctl status <service-name>`
3. Check disk space: `df -h`
4. Monitor system resources: `htop`