#!/bin/bash
# Docker installation: Docker CE, compose plugin, daemon config
# Requires: utils.sh. NVIDIA Container Toolkit is in nvidia.sh

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

install_docker() {
    print_step "Installing Docker"
    require_ubuntu

    if check_command docker; then
        local ver
        ver=$(docker --version 2>/dev/null | cut -d' ' -f3 | sed 's/,//' || echo "unknown")
        print_info "Docker already installed (version $ver)"
        if [[ -n "${YES_TO_ALL:-}" ]] && [[ "$YES_TO_ALL" -eq 1 ]]; then
            print_info "Skipping (--yes, already installed)"
            return 0
        fi
        if [[ -z "${FORCE_REINSTALL:-}" ]] && ! prompt_yes_no "Reinstall Docker?" "n"; then
            print_info "Skipping Docker installation"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would install Docker CE and compose plugin"
        return 0
    fi

    run_sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    run_sudo apt-get update
    run_sudo apt-get install -y ca-certificates curl gnupg2 software-properties-common apt-transport-https lsb-release

    run_sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | run_sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | run_sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    run_sudo apt-get update
    run_sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

    run_sudo usermod -aG docker "$USER"
    run_sudo systemctl start docker
    run_sudo systemctl enable docker

    print_success "Docker installed (logout/login required for group)"
}

configure_docker_daemon() {
    local max_size="${DOCKER_LOG_MAX_SIZE:-10m}"
    local max_file="${DOCKER_LOG_MAX_FILE:-3}"
    local storage_driver="${DOCKER_STORAGE_DRIVER:-overlay2}"

    print_step "Configuring Docker daemon"

    run_sudo mkdir -p /etc/docker
    run_sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "$max_size",
    "max-file": "$max_file"
  },
  "storage-driver": "$storage_driver",
  "default-runtime": "runc"
}
EOF

    if [[ "$DRY_RUN" -ne 1 ]]; then
        run_sudo systemctl restart docker
    fi
    print_success "Docker daemon configured"
}

verify_docker() {
    if check_command docker; then
        print_success "Docker: $(docker --version 2>/dev/null || echo 'installed')"
    else
        print_error "Docker: not found"
        return 1
    fi
    if docker compose version 2>/dev/null || docker-compose --version 2>/dev/null; then
        print_success "Docker Compose: $(docker compose version 2>/dev/null || docker-compose --version 2>/dev/null | head -1)"
    else
        print_warning "Docker Compose: not found"
    fi
    return 0
}
