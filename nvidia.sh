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







# Install nvidia-docker
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list
sudo apt-get update
sudo apt-get install -y nvidia-docker2
sudo pkill -SIGHUP dockerd