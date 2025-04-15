# Purge old install
sudo apt-get remove --purge '^nvidia-.*'
sudo apt-get remove --purge '^libnvidia-.*'
sudo apt-get remove --purge '^cuda-.*'

# Install build essentials
# OLD
# sudo apt-get install linux-{headers,image,image-extra}-$(uname -r) build-essential
sudo apt install linux-headers-$(uname -r)

sudo apt install build-essential

sudo update-initramfs -u

# Get cuda
# Source: https://docs.nvidia.com/cuda/cuda-installation-guide-linux/#meta-packages
# Remove old key
#sudo apt-key del 7fa2af80

# Ubuntu 20.04
#wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda_12.3.1_545.23.08_linux.run
#sudo sh cuda_12.3.1_545.23.08_linux.run

# Ubuntu 22.04
wget https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/cuda_12.3.1_545.23.08_linux.run
sudo sh cuda_12.3.1_545.23.08_linux.run 

# Install Nvidia Driver
sudo apt install nvidia-driver-535
# Check available version
apt search nvidia

#sudo apt install libnvidia-common-<version>
#sudo apt install libnvidia-gl-<version>
#sudo apt install nvidia-driver-<version>

sudo apt install libnvidia-common-535
sudo apt install libnvidia-gl-535
sudo apt install nvidia-driver-535


sudo apt install libnvidia-common-525
sudo apt install libnvidia-gl-525
sudo apt install nvidia-driver-525


# If you run into issues with driver not installing or starting disable secure boot

# check that the driver installed
nvidia-smi




# CUDA Toolkit 12.8
wget https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin
sudo mv cuda-ubuntu2404.pin /etc/apt/preferences.d/cuda-repository-pin-600
wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda-repo-ubuntu2404-12-8-local_12.8.1-570.124.06-1_amd64.deb
sudo dpkg -i cuda-repo-ubuntu2404-12-8-local_12.8.1-570.124.06-1_amd64.deb
sudo cp /var/cuda-repo-ubuntu2404-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
sudo apt-get update
sudo apt-get -y install cuda-toolkit-12-8


# Test nvidia + docker
docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi
