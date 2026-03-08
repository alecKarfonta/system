#!/bin/bash
# NVIDIA GPU setup: drivers, CUDA toolkit, container toolkit
# Requires: utils.sh, Docker installed first for container toolkit

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

resolve_cuda_version() {
    local ubuntu_ver
    ubuntu_ver=$(detect_ubuntu_version)
    if [[ -n "${CUDA_VERSION:-}" ]]; then
        echo "$CUDA_VERSION"
        return
    fi
    case "$ubuntu_ver" in
        24.04) echo "${CUDA_UBUNTU_2404:-12.8}" ;;
        22.04) echo "${CUDA_UBUNTU_2204:-12.3}" ;;
        20.04) echo "12.3" ;;
        *) echo "12.3" ;;
    esac
}

resolve_driver_version() {
    if [[ -n "${GPU_DRIVER_VERSION:-}" ]]; then
        echo "$GPU_DRIVER_VERSION"
        return
    fi
    echo "550"
}

install_nvidia() {
    print_step "Installing NVIDIA drivers and CUDA"
    require_ubuntu

    if ! has_nvidia_gpu; then
        print_warning "No NVIDIA GPU detected. Skipping NVIDIA setup."
        return 0
    fi

    local driver_ver
    driver_ver=$(resolve_driver_version)
    local cuda_ver
    cuda_ver=$(resolve_cuda_version)
    local ubuntu_ver
    ubuntu_ver=$(detect_ubuntu_version)

    print_info "Driver: $driver_ver, CUDA: $cuda_ver, Ubuntu: $ubuntu_ver"

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install nvidia-driver-$driver_ver, cuda-toolkit, nvidia-container-toolkit"
        return 0
    fi

    run_sudo apt-get update
    run_sudo apt-get remove --purge '^nvidia-.*' '^libnvidia-.*' '^cuda-.*' 2>/dev/null || true
    run_sudo apt-get install -y linux-headers-$(uname -r) build-essential
    run_sudo update-initramfs -u

    run_sudo apt-get install -y "nvidia-driver-$driver_ver"
    run_sudo apt-get install -y "libnvidia-common-$driver_ver" "libnvidia-gl-$driver_ver" 2>/dev/null || true

    print_info "Driver installed. Reboot may be required. Continuing with CUDA..."

    if [[ "$ubuntu_ver" == "24.04" ]] && [[ "$cuda_ver" == "12.8" ]]; then
        local pin_file="/etc/apt/preferences.d/cuda-repository-pin-600"
        if [[ ! -f "$pin_file" ]]; then
            (cd /tmp && wget -q https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2404/x86_64/cuda-ubuntu2404.pin && run_sudo mv cuda-ubuntu2404.pin "$pin_file")
        fi
        local deb_file="cuda-repo-ubuntu2404-12-8-local_12.8.1-570.124.06-1_amd64.deb"
        (cd /tmp && wget -q "https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/$deb_file" && run_sudo dpkg -i "$deb_file")
        run_sudo cp /var/cuda-repo-ubuntu2404-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
        run_sudo apt-get update
        run_sudo apt-get install -y cuda-toolkit-12-8
    elif [[ "$ubuntu_ver" == "22.04" ]] && [[ "$cuda_ver" == "12.3" ]]; then
        local runfile="cuda_12.3.1_545.23.08_linux.run"
        (cd /tmp && wget -q "https://developer.download.nvidia.com/compute/cuda/12.3.1/local_installers/$runfile" && run_sudo sh "$runfile" --silent --toolkit)
    else
        print_warning "CUDA $cuda_ver for Ubuntu $ubuntu_ver: manual installation may be needed"
        print_info "See nvidia/nvidia.sh for runfile URLs"
    fi

    print_success "NVIDIA driver and CUDA installed"
}

install_nvidia_container_toolkit() {
    print_step "Installing NVIDIA Container Toolkit"
    require_ubuntu

    if ! has_nvidia_gpu; then
        print_warning "No NVIDIA GPU detected. Skipping container toolkit."
        return 0
    fi

    if ! check_command docker; then
        print_error "Docker must be installed first for NVIDIA Container Toolkit"
        return 1
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install nvidia-container-toolkit"
        return 0
    fi

    local distribution
    distribution=$(. /etc/os-release; echo $ID$VERSION_ID | sed 's/\.//g')
    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | run_sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg
    curl -s -L "https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list" | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        run_sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    run_sudo apt-get update
    run_sudo apt-get install -y nvidia-container-toolkit
    run_sudo nvidia-ctk runtime configure --runtime=docker
    run_sudo systemctl restart docker

    print_success "NVIDIA Container Toolkit installed"
}

verify_nvidia() {
    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_name
        gpu_name=$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | head -1)
        print_success "NVIDIA: $gpu_name"
    else
        print_warning "NVIDIA: nvidia-smi not found"
        return 0
    fi
    return 0
}

verify_nvidia_docker() {
    if ! check_command docker; then
        return 0
    fi
    if docker run --rm --gpus all nvidia/cuda:12.0.0-base-ubuntu22.04 nvidia-smi >/dev/null 2>&1; then
        print_success "NVIDIA Docker: GPU accessible in containers"
    else
        print_warning "NVIDIA Docker: GPU test failed (driver may need reboot)"
    fi
    return 0
}
