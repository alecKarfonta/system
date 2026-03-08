# Setup Script Notes

## Current Goal
Unified extensible setup script (setup.sh) for new Ubuntu machines: core packages, Docker, optional GPU, Python/Conda, and cluster support (MicroK8s).

## What Was Implemented
- `setup.sh` - main orchestrator with CLI (--role, --gpu, --profile, etc.)
- `setup.conf` - configurable defaults
- `modules/` - core, docker, nvidia, python, services, cluster, utils
- `profiles/` - minimal, ml-dev, gpu-worker, cluster-master

## Usage
```bash
./setup.sh --role standalone --gpu
./setup.sh --role cluster-worker --master-ip 192.168.1.50 --join-token 25000/xxx/yyy --gpu
./setup.sh --role cluster-master --gpu --enable-kubeflow
./setup.sh --profile ml-dev --gpu --dry-run --yes
```

## Problems / Things to Try
- NVIDIA installer may need reboot before nvidia-smi works
- MicroK8s add-node output format: run on master, copy join command
- Cluster worker needs both --master-ip and --join-token

## Possible Solutions
- Add post-reboot verification script
- Document join token extraction in README
