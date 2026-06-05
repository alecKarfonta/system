# Legacy Manual Deployments

**Archived — do not extend.**

This directory contains the pre-k3s era of system management: shell bootstrap
scripts, docker-compose stacks, and one-off deployment folders. Everything here
is frozen for reference only.

Active development lives at the repository root under `cluster/` and `workloads/`.

## Contents

| Path | Description | Entry point |
|------|-------------|-------------|
| [ollama-rtx5090/](ollama-rtx5090/) | Ollama on RTX 5090 with GPU fan control | `./run.sh` |
| [ml-dev-stack/](ml-dev-stack/) | Multi-service docker-compose dev environment | `docker compose up` |
| [jupyter-server/](jupyter-server/) | Production Jupyter container | `./run.sh` |
| [jupyter/](jupyter/) | Lightweight Jupyter container | `./run.sh` |
| [devpi/](devpi/) | Local PyPI mirror (Docker) | `docker compose up` |
| [kubernetes/](kubernetes/) | microk8s / kubeadm notes (superseded) | — |
| [ubuntu-ml-init/](ubuntu-ml-init/) | Full-machine Ubuntu ML bootstrap | `./init.sh` |
| [talker/](talker/) | Talker project restore script | `./restore.sh` |
| [setup/](setup/) | Legacy complete-setup orchestrator | `./complete_setup.sh` |
| [anaconda/](anaconda/) | Conda install scripts | — |
| [docker/](docker/) | Docker install + shared Dockerfiles | — |
| [ml/](ml/) | vLLM / PyTorch install scripts | — |
| [nvidia/](nvidia/) | NVIDIA driver / CUDA setup | — |
| [postgres/](postgres/) | Native PostgreSQL install | — |
| [docs/](docs/) | Legacy documentation | — |

## Usage

Run scripts from within each deployment directory. Paths were updated where
needed during the archive move, but these stacks are unmaintained — expect
rough edges.
