# Unified Setup Script (setup.sh)

Single extensible script for configuring new Ubuntu machines: base system, Docker, optional GPU, Python/Conda, and MicroK8s cluster support.

## Quick Reference

```bash
./setup.sh --role standalone --gpu
./setup.sh --role cluster-master --gpu --enable-kubeflow
./setup.sh --role cluster-worker --master-ip 192.168.1.50 --join-token 25000/xxx/yyy --gpu
./setup.sh --profile ml-dev --dry-run --yes
```

## Roles

| Role | Description |
|------|-------------|
| standalone | ML development machine: core, Docker, Python, swap, SSH |
| cluster-master | MicroK8s cluster controller: core, Docker, services, MicroK8s |
| cluster-worker | Join existing cluster: core, Docker, MicroK8s join |

## Options

| Option | Description |
|--------|-------------|
| --role ROLE | standalone, cluster-master, cluster-worker |
| --gpu | Install NVIDIA drivers, CUDA, container toolkit |
| --profile NAME | Load profiles/NAME.conf |
| --dry-run | Show actions without executing |
| --yes | Non-interactive, skip prompts for existing installs |
| --master-ip IP | Master node IP (cluster-worker) |
| --join-token T | Token from `microk8s add-node` (cluster-worker) |
| --enable-kubeflow | Deploy Kubeflow via Juju (cluster-master) |
| --core, --docker, --python, --services, --swap, --ssh | Force individual modules |

## Profiles

| Profile | Use Case |
|---------|----------|
| minimal | Core + Docker only |
| ml-dev | Full ML stack with services |
| gpu-worker | GPU worker for cluster |
| cluster-master | Cluster controller config |

## Configuration

Edit `setup.conf` or create `profiles/custom.conf` to override:

- SWAP_SIZE, CORE_PACKAGES
- GPU_DRIVER_VERSION, CUDA_VERSION
- METALLB_IP_RANGE, MICROK8S_ADDONS
- REQUIREMENTS_FILE, CONDA_INSTALL_DIR

## Cluster Workflow

1. On master: `./setup.sh --role cluster-master --gpu`
2. On master: `microk8s add-node` (copy the join command)
3. On worker: `./setup.sh --role cluster-worker --master-ip MASTER_IP --join-token TOKEN --gpu`
4. Token format: the part after the colon, e.g. `25000/abc123/def456`

## Files

- `setup.sh` - Main entry point
- `setup.conf` - Default configuration
- `modules/` - core, docker, nvidia, python, services, cluster, utils
- `profiles/` - minimal, ml-dev, gpu-worker, cluster-master
