## Service Management
# Start service
# Start kubelet
sudo systemctl start kubelet
# Enable on reboot
sudo systemctl enable kubelet

## Service Management



## Cluster Management
# Pull kubernetes images
sudo kubeadm config images pull

# Init cluster
sudo kubeadm init --apiserver-advertise-address=192.168.1.201 --pod-network-cidr=172.16.0.0/16
# This command will output a token to use when joining worker nodes

# Apply a networking type: https://kubernetes.io/docs/concepts/cluster-administration/addons/
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

## Cluster Management



## Cluster Status
# Show nodes in cluster
kubectl get nodes

# Show more details on nodes
kubectl get nodes -o wide

## Cluster Status
