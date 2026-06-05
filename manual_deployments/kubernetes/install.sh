# Purge old

# Remove Kubernetes
kubeadm reset
sudo apt-get purge kubeadm kubectl kubelet kubernetes-cni kube*   
sudo apt-get autoremove  
sudo rm -rf ~/.kube

# Remove Juju
sudo snap remove --purge  juju


# Remove microk8s
sudo snap remove --purge  microk8s

