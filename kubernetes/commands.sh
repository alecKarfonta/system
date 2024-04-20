



# Source: https://phoenixnap.com/kb/install-kubernetes-on-ubuntu


# Download keys
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo tee /usr/share/keyrings/kubernetes.gpg

# Add repositories
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/kubernetes.gpg] http://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list

sudo snap install kubeadm --classic

sudo snap install kubelet --classic

sudo snap install kubectl --classic

# Verify install
kubeadm version


sudo nano /etc/modules-load.d/containerd.conf

# Add
# overlay
# br_netfilter

sudo modprobe overlay

sudo modprobe br_netfilter

sudo nano /etc/sysctl.d/kubernetes.conf

net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1

# Reload config
sudo sysctl --system

 sudo nano /etc/hosts

 # Add
# 192.168.1.4 worker01
# 192.168.1.201 master-node


# Init kubernetes on master
sudo nano /etc/default/kubelet

# Add
# KUBELET_EXTRA_ARGS="--cgroup-driver=cgroupfs"

# Reload config
systemctl daemon-reload

# Restart kubelet
sudo snap restart kubelet

sudo nano /etc/docker/daemon.json

sudo apt-get install -y kubectl kubeadm kubelet kubernetes-cni docker.io




# Source WORKING!!!
# https://medium.com/clarusway/kubernetes-step-by-step-setup-guide-for-beginners-cba307250a6c

# Set hostname
# On master
sudo hostnamectl set-hostname kubemaster

# On worker
sudo hostnamectl set-hostname kubeworker

# On Both machines
# Add repositories
sudo apt-get update && sudo apt-get install -y apt-transport-https gnupg2
curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee -a /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update

# Install 
sudo apt-get install -y kubectl kubeadm kubelet kubernetes-cni docker.io

# Start docker
sudo systemctl start docker
sudo systemctl enable docker
# Start kubelet
sudo systemctl start kubelet
sudo systemctl enable kubelet

# Add docker user to current user group
sudo usermod -aG docker $USER
newgrp docker


# Allow brdged connections
cat << EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sudo sysctl — system


# On Master
# Pull images
sudo kubeadm config images pull

# Set listen up address
sudo kubeadm init --apiserver-advertise-address=192.168.1.201 --pod-network-cidr=172.16.0.0/16



kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml




kubeadm join 192.168.1.201:6443 --token 1aiej0.kf0t4on7c7bm2hlu \
--discovery-token-ca-cert-hash sha256:0e2abfb56733665c0e620423337f34be2a4f3c4b8d1ea44dff85666ddf722c02

