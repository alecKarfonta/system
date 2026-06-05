## Service Management
# Start service
# Start kubelet
sudo systemctl start kubelet
# Enable on reboot
sudo systemctl enable kubelet

## Service Management



## Cluster Management
# View config
kubectl config view

# List users
kubectl config view -o jsonpath='{.users[*].name}' 

# Get user password
kubectl config view -o jsonpath='{.users[?(@.name == "e2e")].user.password}'

# Delete user
kubectl config unset users.[USERNAME]


# List contexts
kubectl config get-contexts  

# Show current context
kubectl config current-context 

# Set cluster to use context
kubectl config use-context [CLUSTER_NAME] 

# set a context utilizing a specific username and namespace.
kubectl config set-context gce --user=cluster-admin --namespace=foo \
  && kubectl config use-context gce

# Pull kubernetes images
sudo kubeadm config images pull

# Init cluster
sudo kubeadm init --apiserver-advertise-address=192.168.1.201 --pod-network-cidr=172.16.0.0/16
# This command will output a token to use when joining worker nodes

# Apply a networking type: https://kubernetes.io/docs/concepts/cluster-administration/addons/
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

# short alias to set/show context/namespace (only works for bash and bash-compatible shells, current context to be set before using kn to set namespace)
alias kx='f() { [ "$1" ] && kubectl config use-context $1 || kubectl config current-context ; } ; f'
alias kn='f() { [ "$1" ] && kubectl config set-context --current --namespace $1 || kubectl config view --minify | grep namespace | cut -d" " -f6 ; } ; f'


## Cluster Management



## Cluster Status
# Show nodes in cluster
kubectl get nodes

# Show more details on nodes
kubectl get nodes -o wide

## Cluster Status
