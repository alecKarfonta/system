

# Setup 

## Snapd
```bash
sudo apt update
sudo apt install snapd
```

## Microk8s

MicroK8s is a lightweight Kubernetes distribution from Canonical that simplifies the process of setting up a Kubernetes cluster. Follow these steps to install and set up MicroK8s:

## Install MicroK8s
https://github.com/canonical/microk8s

1. **Install MicroK8s Package
```bash
sudo snap install microk8s --classic --channel=1.26/stable
```

2. **Add Current User to MicroK8s Group
This allows the current user to run MicroK8s commands without sudo.
```bash
sudo usermod -a -G microk8s $USER
newgrp microk8s
```

```bash
sudo chown -f -R $USER ~/.kube
```

3. **Alias MicroK8s kubectl**
Allows you to use 'kubectl' instead of 'microk8s kubectl'
```bash
sudo snap alias microk8s.kubectl kubectl
```


4. Check Cluster Information**
```bash
kubectl cluster-info
```

Enable add-ons
```bash
microk8s enable dns hostpath-storage ingress metallb:10.64.140.43-10.64.140.49 rbac
```

## JuJU
Source: https://charmed-kubeflow.io/docs/get-started-with-charmed-kubeflow
5. Install JuJu
```bash
sudo snap install juju --classic --channel=3.1/stable
```

6. Make local file
```bash
mkdir -p ~/.local/share
```

7. Boostrap JuJu to MicroK8s
```bash
microk8s config | juju add-k8s my-k8s --client
juju bootstrap my-k8s
```


6. Add Kubeflow
```bash
juju add-model kubeflow
```

7. Launch Kubeflow
```bash
juju deploy kubeflow --trust
```

**Check Ip of load balancer**
```bash
microk8s kubectl -n kubeflow get svc istio-ingressgateway-workload -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

**Configure JuJu ips**
```bash
juju config dex-auth public-url=http://10.64.140.43.nip.io
juju config oidc-gatekeeper public-url=http://10.64.140.43.nip.io
```

**Set default login**
```bash
juju config dex-auth static-username=admin
juju config dex-auth static-password=admin
```


**Check kubernetes status**
```bash
kubectl get svc --all-namespaces
```

**Describe a Specific Service**
```bash
kubectl describe svc <service-name> -n <namespace>
```

**Get service endpoints**
```bash
kubectl get endpoints <service-name> -n <namespace>
```

# Manage Cluster
These commands are useful for managing nodes and resources in your MicroK8s cluster.


## Add a node to a cluster
https://microk8s.io/docs/clustering

1. **On the control plane machine run the command** 
```bash
microk8s add-node
``` 
2. **Start worker node**
On the worker node run the command given in the above output with the --worker flag
```bash
microk8s join 192.168.1.50:25000/750807748f048d8bce965561b12e21c6/25f9de53f042 --worker
```
3. **View nodes in a cluster**
```bash
microk8s kubectl get no
```
4. **Remove node from host**
```bash
microk8s remove-node 10.22.254.79
```
5. **Remove from client**
```bash
microk8s leave
```

## Enable GPU Compute
Source: https://microk8s.io/docs/addon-gpu
For workloads requiring GPU, enable GPU support in your MicroK8s cluster.

1. **Show allocatable GPUs**
```bash
microk8s kubectl get node -o jsonpath="{range .items[*]}{..allocatable}{'\n'}{end}"
```

2. **Enable gpu on host**
```bash
microk8s enable gpu
```


## Context

**Show contexts**
```bash
kubectl config get-contexts
```


## Users

**View users**
```bash
kubectl config view -o jsonpath='{.users[*].name}' 
```

## View pods

**Show all pods**
```bash
kubectl get pods --all-namespaces
```

**Describe pods**
```bash
kubectl describe pods --all-namespaces
```

**Show all running pods**
```bash
kubectl get pods --field-selector=status.phase==Running --all-namespaces
```

**Show Kubeflow pods**
```bash
microk8s kubectl get po -n kubeflow
```

**Show pod logs*
```bash
microk8s kubectl logs -n kubeflow
```



# Namespaces

## Show namesspaces
```bash
microk8s kubectl get namespaces
```


**Show all pods from all namespaces
```bash
microk8s kubectl get pods --all-namespaces
```



# Monitoring

## Micok8s
**Show everything**
```bash
microk8s kubectl get all --all-namespaces
```

**Describe nodes**
```bash
kubectl describe node
```

## Dashboard
Accessing the Kubernetes dashboard on MicroK8s.
1. **Enable the Dashboard**
```bash
microk8s enable dashboard
```

2. Create access token (unique per deployment)
```bash
microk8s kubectl create token default
```

3. **Forward port**
```bash
microk8s kubectl port-forward -n kube-system service/kubernetes-dashboard 10443:8443
```

4. **Create dashboard user**
Source: https://github.com/kubernetes/dashboard/blob/master/docs/user/access-control/creating-sample-user.md
```bash
kubectl apply -f dashboard-adminuser.yaml
```

5. **Define user permission**
```bash
kubectl apply -f rbac.yaml
```

6. **Create access token for system user**
```bash
kubectl -n kube-system create token admin-user
```

6. **Dashboard proxy**
```bash
microk8s dashboard-proxy
```


## Octane resource visualizer
1. **Download
```bash
wget https://github.com/vmware-archive/octant/releases/download/v0.25.1/octant_0.25.1_Linux-64bit.deb
```

2. **Install
```bash
sudo dpkg -i octant_0.25.1_Linux-64bit.deb
```


# Add-ons

**Show add ons
```bash
microk8s status
```


# Images

List all images used by all containers
```bash
kubectl get pods --all-namespaces -o jsonpath="{.items[*].spec['initContainers', 'containers'][*].image}" |\
tr -s '[[:space:]]' '\n' |\
sort |\
uniq -c
```

# Nuke

Delete gpu operator
```bash
Kubectl delete deploy gpu-operator
```
```bash
kubectl delete deploy gpu-operator-node-feature-discovery-master
```

Delete gpu operator namespace
```bash
kubectl delete namespace gpu-operator
```

Delete cluster roles
```bash
kubectl delete  ClusterRoles gpu-operator
```

Delete all non running pods
```bash
kubectl delete pods --field-selector=status.phase!=Running --all-namespaces
```

Delete all pods
```bash
kubectl delete --all namespaces
```

Delete all deploy pods
```bash
kubectl delete --all deployments --namespace=foo
```

Delete pods in namespace
```bash
kubectl delete --all pods --namespace=gpu-operator-resources
```

Delete everything everywhere
```bash
kubectl delete all --all --all-namespaces
```


Delete Kubeflow
```bash
kubectl delete ns kubeflow
```
Persistent volumes
```bash
kubectl delete pvc --all -n kubeflow
kubectl delete pv --all
```

Delete Microk8s

1. **Stop the service**
```bash
microk8s stop
```

2. **Remove deployments**
```bash
microk8s reset  
```

3. **Remove service**
```bash
sudo snap remove microk8s --purge
```

4. **Clean up**
Remove local files created by Microk8s
```bash
sudo rm -rf ~/.kube
sudo rm -rf /var/snap/microk8s
```

5. **Remove Snapd**
Remove snapd that is installed by JuJu
```bash
sudo apt purge snapd -y
sudo apt autoremove -y
```

6. **Remove JuJu**
```bash
sudo snap remove juju --purge
```