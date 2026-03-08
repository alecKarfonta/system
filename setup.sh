#!/bin/bash
# Unified Ubuntu ML System Setup Script
# Usage: ./setup.sh [options]
#
# Options:
#   --role ROLE          standalone | cluster-worker | cluster-master
#   --gpu                Install NVIDIA drivers and CUDA
#   --profile NAME       Load profile from profiles/NAME.conf
#   --dry-run            Print actions without executing
#   --yes                Non-interactive, accept defaults
#   --master-ip IP       For cluster-worker: master node IP
#   --join-token TOKEN   For cluster-worker: join token from microk8s add-node
#   --enable-kubeflow    For cluster-master: deploy Kubeflow
#   --core               Install core system only
#   --docker             Install Docker
#   --python             Install Miniconda
#   --services           Deploy docker-compose services
#   --swap               Configure swap file
#   --ssh                Configure SSH server

set -e
trap 'log "Setup failed at line $LINENO"; exit 1' ERR

SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
: "${SCRIPT_ROOT:?SCRIPT_ROOT could not be determined}"
cd "$SCRIPT_ROOT"

# Load config (SCRIPT_ROOT set above; setup.conf may override other vars)
if [[ -f "$SCRIPT_ROOT/setup.conf" ]]; then
    # shellcheck source=setup.conf
    source "$SCRIPT_ROOT/setup.conf"
fi
# Ensure SCRIPT_ROOT is preserved
SCRIPT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Source utils
source "$SCRIPT_ROOT/modules/utils.sh"
export SCRIPT_ROOT

# Defaults
ROLE="standalone"
INSTALL_GPU=0
DRY_RUN=0
YES_TO_ALL=0
INSTALL_KUBEFLOW=0
CLUSTER_MASTER_IP=""
CLUSTER_JOIN_TOKEN=""
PROFILE=""

# Module flags (empty = use role defaults)
DO_CORE=""
DO_DOCKER=""
DO_PYTHON=""
DO_SERVICES=""
DO_SWAP=""
DO_SSH=""
DO_CLUSTER=""
DO_NVIDIA=""

usage() {
    cat <<EOF
Usage: $0 [options]

Roles:
  standalone        ML development machine (default)
  cluster-master    Create new MicroK8s cluster
  cluster-worker    Join existing cluster

Options:
  --role ROLE       standalone | cluster-worker | cluster-master
  --gpu             Install NVIDIA drivers, CUDA, container toolkit
  --profile NAME    Load profiles/NAME.conf
  --dry-run         Show actions without executing
  --yes             Non-interactive
  --master-ip IP    Master IP (cluster-worker)
  --join-token T    Join token (cluster-worker)
  --enable-kubeflow Deploy Kubeflow (cluster-master)

  --core            Force install core packages
  --docker          Force install Docker
  --python          Force install Miniconda
  --services        Force deploy compose services
  --swap            Force configure swap
  --ssh             Force configure SSH

Examples:
  $0 --role standalone --gpu
  $0 --role cluster-worker --master-ip 192.168.1.50 --join-token 25000/xxx/yyy --gpu
  $0 --role cluster-master --gpu --enable-kubeflow
EOF
}

# Parse args
while [[ $# -gt 0 ]]; do
    case "$1" in
        --role) ROLE="$2"; shift 2 ;;
        --gpu) INSTALL_GPU=1; shift ;;
        --profile) PROFILE="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; export DRY_RUN; shift ;;
        --yes) YES_TO_ALL=1; export YES_TO_ALL; shift ;;
        --master-ip) CLUSTER_MASTER_IP="$2"; shift 2 ;;
        --join-token) CLUSTER_JOIN_TOKEN="$2"; shift 2 ;;
        --enable-kubeflow) INSTALL_KUBEFLOW=1; export ENABLE_KUBEFLOW=1; shift ;;
        --core) DO_CORE=1; shift ;;
        --docker) DO_DOCKER=1; shift ;;
        --python) DO_PYTHON=1; shift ;;
        --services) DO_SERVICES=1; shift ;;
        --swap) DO_SWAP=1; shift ;;
        --ssh) DO_SSH=1; shift ;;
        -h|--help) usage; exit 0 ;;
        *) print_error "Unknown option: $1"; usage; exit 1 ;;
    esac
done

# Load profile
if [[ -n "$PROFILE" ]] && [[ -f "$SCRIPT_ROOT/profiles/$PROFILE.conf" ]]; then
    # shellcheck source=/dev/null
    source "$SCRIPT_ROOT/profiles/$PROFILE.conf"
    print_info "Loaded profile: $PROFILE"
fi

# Resolve module flags from role
resolve_modules() {
    case "$ROLE" in
        standalone)
            [[ -z "$DO_CORE" ]] && DO_CORE=1
            [[ -z "$DO_DOCKER" ]] && DO_DOCKER=1
            [[ -z "$DO_PYTHON" ]] && DO_PYTHON=1
            [[ -z "$DO_SERVICES" ]] && DO_SERVICES=0
            [[ -z "$DO_SWAP" ]] && DO_SWAP=1
            [[ -z "$DO_SSH" ]] && DO_SSH=1
            [[ -z "$DO_CLUSTER" ]] && DO_CLUSTER=0
            [[ -z "$DO_NVIDIA" ]] && DO_NVIDIA=$INSTALL_GPU
            ;;
        cluster-master)
            [[ -z "$DO_CORE" ]] && DO_CORE=1
            [[ -z "$DO_DOCKER" ]] && DO_DOCKER=1
            [[ -z "$DO_PYTHON" ]] && DO_PYTHON=0
            [[ -z "$DO_SERVICES" ]] && DO_SERVICES=1
            [[ -z "$DO_SWAP" ]] && DO_SWAP=1
            [[ -z "$DO_SSH" ]] && DO_SSH=1
            [[ -z "$DO_CLUSTER" ]] && DO_CLUSTER=1
            [[ -z "$DO_NVIDIA" ]] && DO_NVIDIA=$INSTALL_GPU
            ;;
        cluster-worker)
            [[ -z "$DO_CORE" ]] && DO_CORE=1
            [[ -z "$DO_DOCKER" ]] && DO_DOCKER=1
            [[ -z "$DO_PYTHON" ]] && DO_PYTHON=0
            [[ -z "$DO_SERVICES" ]] && DO_SERVICES=0
            [[ -z "$DO_SWAP" ]] && DO_SWAP=1
            [[ -z "$DO_SSH" ]] && DO_SSH=1
            [[ -z "$DO_CLUSTER" ]] && DO_CLUSTER=1
            [[ -z "$DO_NVIDIA" ]] && DO_NVIDIA=$INSTALL_GPU
            ;;
        *) print_error "Unknown role: $ROLE"; exit 1 ;;
    esac
}

# Banner
echo -e "${BLUE}"
cat <<'BANNER'
  Ubuntu ML System Setup
  Extensible system dependency installer
BANNER
echo -e "${NC}"

detect_os
print_info "OS: $OS, Distro: $DISTRO ${DISTRO_VERSION:-}"
if has_nvidia_gpu; then
    print_info "NVIDIA GPU: $(detect_nvidia_gpu)"
fi

resolve_modules

if [[ "$DRY_RUN" -eq 1 ]]; then
    print_warning "DRY RUN - no changes will be made"
fi

# Core
if [[ "$DO_CORE" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/core.sh"
    install_core
fi
if [[ "$DO_SWAP" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/core.sh"
    install_swap
fi
if [[ "$DO_SSH" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/core.sh"
    install_ssh
fi

# Docker
if [[ "$DO_DOCKER" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/docker.sh"
    install_docker
    configure_docker_daemon
fi

# NVIDIA (after Docker for container toolkit)
if [[ "$DO_NVIDIA" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/nvidia.sh"
    install_nvidia
    install_nvidia_container_toolkit
fi

# Python
if [[ "$DO_PYTHON" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/python.sh"
    install_python
    install_requirements
fi

# Cluster
if [[ "$DO_CLUSTER" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/cluster.sh"
    export CLUSTER_MASTER_IP CLUSTER_JOIN_TOKEN
    export ENABLE_GPU=$INSTALL_GPU
    if [[ "$ROLE" == "cluster-master" ]]; then
        install_cluster_master
        [[ "$INSTALL_KUBEFLOW" -eq 1 ]] && install_kubeflow
    elif [[ "$ROLE" == "cluster-worker" ]]; then
        if [[ -z "$CLUSTER_MASTER_IP" ]] || [[ -z "$CLUSTER_JOIN_TOKEN" ]]; then
            print_warning "Worker role requires --master-ip and --join-token. Run on master: microk8s add-node"
        else
            install_cluster_worker
        fi
    fi
fi

# Services
if [[ "$DO_SERVICES" -eq 1 ]]; then
    source "$SCRIPT_ROOT/modules/services.sh"
    install_services
fi

# Verification
echo -e "\n${BLUE}=== Verification ===${NC}"
source "$SCRIPT_ROOT/modules/core.sh"
verify_core
verify_swap
verify_ssh 2>/dev/null || true

[[ "$DO_DOCKER" -eq 1 ]] && { source "$SCRIPT_ROOT/modules/docker.sh"; verify_docker; }
[[ "$DO_NVIDIA" -eq 1 ]] && { source "$SCRIPT_ROOT/modules/nvidia.sh"; verify_nvidia; verify_nvidia_docker; }
[[ "$DO_PYTHON" -eq 1 ]] && { source "$SCRIPT_ROOT/modules/python.sh"; verify_python; }
[[ "$DO_CLUSTER" -eq 1 ]] && { source "$SCRIPT_ROOT/modules/cluster.sh"; verify_cluster; }
[[ "$DO_SERVICES" -eq 1 ]] && { source "$SCRIPT_ROOT/modules/services.sh"; verify_services; }

echo -e "\n${GREEN}Setup complete.${NC}"
echo "Log: $LOG_FILE"
if [[ "$DO_DOCKER" -eq 1 ]]; then
    echo "Log out and back in for docker group, or run: newgrp docker"
fi
if [[ "$DO_NVIDIA" -eq 1 ]]; then
    echo "Reboot may be required for NVIDIA driver."
fi
