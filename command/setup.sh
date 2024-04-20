
# WARNING : This gist in the current form is a collection of command examples. Please exercise caution where mentioned.

# Setup a swap
sudo fallocate -l 64G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Set up ssh
sudo apt update
sudo apt install openssh-server
sudo ufw allow ssh

# Docker
sudo apt-get update
sudo apt-get remove docker docker-engine docker.io
sudo apt install docker.io
sudo systemctl start docker
sudo systemctl enable docker
docker --version

# Put the user in the docker group
sudo usermod -a -G docker $USER
newgrp docker

# Nvidia Docker
sudo apt install curl
distribution=$(. /etc/os-release;echo $ID$VERSION_ID)
curl -s -L https://nvidia.github.io/nvidia-docker/gpgkey | sudo apt-key add -
curl -s -L https://nvidia.github.io/nvidia-docker/$distribution/nvidia-docker.list | sudo tee /etc/apt/sources.list.d/nvidia-docker.list

sudo apt-get update && sudo apt-get install -y nvidia-container-toolkit
sudo systemctl restart docker

# Check Docker image
docker run --gpus all nvidia/cuda:12.3.2-devel-ubi8 nvidia-smi

## Erase all Docker images [!!! CAUTION !!!]
# docker rmi -f $(docker images -a -q)

## Erase one Docker image  [!!! CAUTION !!!]
# docker ps
# docker rmi -f image_id

## Running GUI Applications
#xhost +local:docker
#docker run --gpus all -it \
#    -e DISPLAY=$DISPLAY \
#    -v /tmp/.X11-unix:/tmp/.X11-unix \
#    nathzi1505:darknet bash

# Docker compose

sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
docker-compose --version


sudo apt-get install mlocate


# Nagios 
sudo apt update

sudo apt install autoconf gcc libc6 make wget unzip apache2 php libapache2-mod-php libgd-dev libssl-dev -y

wget https://assets.nagios.com/downloads/nagioscore/releases/nagios-4.4.7.tar.gz

tar xzf nagios-4.4.7.tar.gz

cd nagios-4.4.7

./configure --with-httpd-conf=/etc/apache2/sites-enabled

make all

make install-groups-users

sudo usermod -aG nagios www-data

make install

sudo make install-init
sudo make install-daemoninit
sudo make install-commandmode
sudo make install-config
sudo make install-webconf

# Create login
sudo htpasswd -c /usr/local/nagios/etc/htpasswd.users server
# Require input password

sudo a2enmod rewrite cgi

sudo ufw allow Apache
sudo ufw reload

systemctl restart apache2

# Setup plugins
sudo apt-get install -y autoconf gcc libc6 libmcrypt-dev make libssl-dev wget bc gawk dc build-essential snmp libnet-snmp-perl gettext
cd /tmp
wget --no-check-certificate -O nagios-plugins.tar.gz https://github.com/nagios-plugins/nagios-plugins/archive/release-2.4.6.tar.gz
tar zxf nagios-plugins.tar.gz

cd /tmp/nagios-plugins-release-2.4.6/
sudo ./tools/setup
sudo ./configure
sudo make
sudo make install

# Purge
# locate nagios | xargs sudo rm -R 
# Nagios End

# Install Sublime
# Source: https://www.sublimetext.com/docs/linux_repositories.html

wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/sublimehq-archive.gpg > /dev/null

echo "deb https://download.sublimetext.com/ apt/stable/" | sudo tee /etc/apt/sources.list.d/sublime-text.list


sudo apt-get update
sudo apt-get install sublime-text



# Rip grep
# Source: https://github.com/BurntSushi/ripgrep?tab=readme-ov-file#installation
brew install ripgrep