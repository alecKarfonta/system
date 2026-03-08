#!/bin/bash
# MicroK8s cluster: master or worker setup
# Requires: utils.sh

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

CLUSTER_MASTER_IP=""
CLUSTER_JOIN_TOKEN=""
CLUSTER_JOIN_TOKEN_HASH=""

install_cluster_master() {
    print_step "Installing MicroK8s (cluster master)"
    require_ubuntu

    local channel="${MICROK8S_CHANNEL:-1.26/stable}"
    local addons="${MICROK8S_ADDONS:-dns hostpath-storage ingress metallb rbac}"
    local metallb_range="${METALLB_IP_RANGE:-10.64.140.43-10.64.140.49}"

    if command -v microk8s >/dev/null 2>&1; then
        print_info "MicroK8s already installed"
        if [[ -n "${YES_TO_ALL:-}" ]] && [[ "$YES_TO_ALL" -eq 1 ]]; then
            print_info "Skipping (--yes, already installed)"
            return 0
        fi
        if [[ -z "${FORCE_REINSTALL:-}" ]] && ! prompt_yes_no "Reinstall MicroK8s?" "n"; then
            print_info "Skipping MicroK8s installation"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install MicroK8s and enable: $addons"
        return 0
    fi

    run_sudo apt-get update
    run_sudo apt-get install -y snapd
    run_sudo snap install microk8s --classic --channel="$channel"
    run_sudo usermod -aG microk8s "$USER"
    run_sudo chown -fR "$USER" ~/.kube 2>/dev/null || true
    run_sudo snap alias microk8s.kubectl kubectl

    print_info "Enabling add-ons: $addons"
    local metallb_arg="metallb:$metallb_range"
    run_sudo microk8s enable $addons 2>/dev/null || run_sudo microk8s enable dns hostpath-storage ingress rbac
    run_sudo microk8s enable metallb 2>/dev/null || run_sudo microk8s enable metallb:"$metallb_range" 2>/dev/null || true

    if [[ -n "${ENABLE_GPU:-}" ]] && [[ "$ENABLE_GPU" == "1" ]] && has_nvidia_gpu; then
        run_sudo microk8s enable gpu
    fi

    print_success "MicroK8s master installed"
    print_info "Run: microk8s add-node   (to get join token for workers)"
}

get_join_token() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would run: microk8s add-node"
        return 0
    fi
    run_sudo microk8s add-node
}

install_cluster_worker() {
    local master_ip="${CLUSTER_MASTER_IP:-}"
    local token="${CLUSTER_JOIN_TOKEN:-}"
    local as_worker="${CLUSTER_AS_WORKER:-1}"

    print_step "Installing MicroK8s (cluster worker)"
    require_ubuntu

    if [[ -z "$master_ip" ]] || [[ -z "$token" ]]; then
        print_error "CLUSTER_MASTER_IP and CLUSTER_JOIN_TOKEN required for worker. Get token from master: microk8s add-node"
        return 1
    fi

    local channel="${MICROK8S_CHANNEL:-1.26/stable}"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install MicroK8s and join $master_ip"
        return 0
    fi

    run_sudo apt-get update
    run_sudo apt-get install -y snapd
    run_sudo snap install microk8s --classic --channel="$channel"
    run_sudo usermod -aG microk8s "$USER"
    run_sudo chown -fR "$USER" ~/.kube 2>/dev/null || true
    run_sudo snap alias microk8s.kubectl kubectl

    if [[ "$as_worker" == "1" ]]; then
        run_sudo microk8s join "$master_ip:$token" --worker
    else
        run_sudo microk8s join "$master_ip:$token"
    fi

    if [[ -n "${ENABLE_GPU:-}" ]] && [[ "$ENABLE_GPU" == "1" ]] && has_nvidia_gpu; then
        run_sudo microk8s enable gpu
    fi

    print_success "MicroK8s worker joined cluster"
}

install_kubeflow() {
    print_step "Installing Kubeflow via Juju"
    require_ubuntu

    if ! command -v microk8s >/dev/null 2>&1; then
        print_error "MicroK8s must be installed first"
        return 1
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would bootstrap Juju and deploy Kubeflow"
        return 0
    fi

    run_sudo snap install juju --classic --channel=3.1/stable
    mkdir -p ~/.local/share
    microk8s config | juju add-k8s my-k8s --client
    juju bootstrap my-k8s
    juju add-model kubeflow
    juju deploy kubeflow --trust

    print_success "Kubeflow deployment started (may take several minutes)"
}

verify_cluster() {
    if command -v microk8s >/dev/null 2>&1; then
        if microk8s status 2>/dev/null | grep -q "microk8s is running"; then
            print_success "MicroK8s: running"
            microk8s kubectl get nodes 2>/dev/null || true
        else
            print_warning "MicroK8s: not running"
        fi
    else
        print_warning "MicroK8s: not installed"
    fi
    return 0
}
