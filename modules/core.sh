#!/bin/bash
# Core system setup: base packages, swap, SSH, firewall
# Requires: utils.sh, setup.conf (optional)

# shellcheck source=utils.sh
[[ -z "${UTILS_LOADED:-}" ]] && source "$(dirname "$0")/utils.sh"

install_core() {
    print_step "Installing core system packages"
    require_ubuntu

    local packages="${CORE_PACKAGES:-build-essential curl wget git software-properties-common ca-certificates gnupg2 apt-transport-https lsb-release openssh-server mlocate}"
    run_sudo apt-get update
    run_sudo apt-get install -y $packages
    print_success "Core packages installed"
}

verify_core() {
    for pkg in curl wget git; do
        if check_command "$pkg"; then
            print_success "$pkg: $(command -v $pkg)"
        else
            print_error "$pkg: not found"
            return 1
        fi
    done
    return 0
}

install_swap() {
    local size="${SWAP_SIZE:-64G}"
    local file="${SWAP_FILE:-/swapfile}"
    local recommended
    recommended=$(get_recommended_swap_size)

    if [[ -n "${SWAP_SIZE_OVERRIDE:-}" ]]; then
        size="$SWAP_SIZE_OVERRIDE"
    fi

    print_step "Configuring swap ($size)"

    if [[ -f "$file" ]]; then
        if swapon --show | grep -q "$file"; then
            print_info "Swap file already active: $file"
            return 0
        fi
    fi

    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] Would create swap file $file ($size)"
        return 0
    fi

    run_sudo fallocate -l "$size" "$file"
    run_sudo chmod 600 "$file"
    run_sudo mkswap "$file"
    run_sudo swapon "$file"

    if ! grep -q "^$file " /etc/fstab 2>/dev/null; then
        echo "$file none swap sw 0 0" | run_sudo tee -a /etc/fstab
    fi

    if [[ -n "${SWAP_SWAPPINESS:-}" ]]; then
        run_sudo sysctl vm.swappiness="${SWAP_SWAPPINESS}"
        if ! grep -q "vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
            echo "vm.swappiness=${SWAP_SWAPPINESS}" | run_sudo tee -a /etc/sysctl.conf
        fi
    fi

    print_success "Swap configured: $file ($size)"
}

verify_swap() {
    if swapon --show 2>/dev/null | grep -q .; then
        print_success "Swap: $(swapon --show | tail -1)"
        return 0
    else
        print_warning "Swap: not configured"
        return 0
    fi
}

install_ssh() {
    print_step "Configuring SSH server"
    require_ubuntu

    run_sudo apt-get install -y openssh-server
    run_sudo systemctl enable ssh 2>/dev/null || run_sudo systemctl enable sshd 2>/dev/null || true
    run_sudo systemctl start ssh 2>/dev/null || run_sudo systemctl start sshd 2>/dev/null || true

    if check_command ufw; then
        run_sudo ufw allow ssh 2>/dev/null || true
        print_info "UFW: ssh rule added (enable with: sudo ufw enable)"
    fi
    print_success "SSH server configured"
}

verify_ssh() {
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        print_success "SSH: service running"
        return 0
    else
        print_warning "SSH: service not running"
        return 0
    fi
}

uninstall_core() {
    print_warning "Uninstalling core packages not implemented (manual removal)"
}
