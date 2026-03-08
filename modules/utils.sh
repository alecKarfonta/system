#!/bin/bash
# Shared utilities for system setup scripts
# Sourced by setup.sh and module scripts

export UTILS_LOADED=1

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Global state (set by main setup.sh)
: "${DRY_RUN:=0}"
: "${LOG_FILE:=/var/log/system-setup.log}"
: "${SCRIPT_ROOT:=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)}"

log() {
    local msg="$*"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" | sudo tee -a "$LOG_FILE" 2>/dev/null || true
}

print_step() {
    local step="$1"
    local total="${2:-}"
    local msg="${3:-$1}"
    if [[ -n "$total" ]] && [[ -n "$3" ]]; then
        echo -e "\n${BLUE}=== Step $step/$total: $msg ===${NC}"
    else
        echo -e "\n${BLUE}=== $msg ===${NC}"
    fi
    log "STEP: $msg"
}

print_success() {
    echo -e "${GREEN}[OK] $1${NC}"
    log "SUCCESS: $1"
}

print_error() {
    echo -e "${RED}[ERROR] $1${NC}"
    log "ERROR: $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}"
    log "WARN: $1"
}

print_info() {
    echo -e "${CYAN}[INFO] $1${NC}"
    log "INFO: $1"
}

run_cmd() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] $*"
    else
        "$@"
    fi
}

run_sudo() {
    if [[ "$DRY_RUN" -eq 1 ]]; then
        print_info "[DRY-RUN] sudo $*"
    else
        sudo "$@"
    fi
}

prompt_yes_no() {
    local prompt="$1"
    local default="${2:-n}"
    local result

    if [[ "$default" == "y" ]]; then
        read -p "$prompt [Y/n]: " result
        result="${result:-y}"
    else
        read -p "$prompt [y/N]: " result
        result="${result:-n}"
    fi
    [[ "$result" =~ ^[Yy]$ ]]
}

prompt_yes_no_silent() {
    local prompt="$1"
    local default="${2:-n}"
    if [[ -n "${YES_TO_ALL:-}" && "$YES_TO_ALL" == "1" ]]; then
        [[ "$default" == "y" ]]
        return
    fi
    prompt_yes_no "$prompt" "$default"
}

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        export OS="linux"
        if [[ -f /etc/os-release ]]; then
            # shellcheck source=/dev/null
            . /etc/os-release
            export DISTRO="${ID:-unknown}"
            export DISTRO_VERSION="${VERSION_ID:-}"
        elif command -v apt >/dev/null 2>&1; then
            export DISTRO="ubuntu"
        elif command -v yum >/dev/null 2>&1; then
            export DISTRO="centos"
        else
            export DISTRO="unknown"
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        export OS="macos"
        export DISTRO="macos"
        export DISTRO_VERSION=""
    else
        export OS="unknown"
        export DISTRO="unknown"
        export DISTRO_VERSION=""
    fi
}

detect_ubuntu_version() {
    if [[ "$DISTRO" != "ubuntu" ]]; then
        echo ""
        return
    fi
    if [[ -f /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        echo "${VERSION_ID:-}"
    else
        lsb_release -rs 2>/dev/null || echo ""
    fi
}

detect_nvidia_gpu() {
    if command -v lspci >/dev/null 2>&1; then
        lspci 2>/dev/null | grep -i nvidia | head -1
    else
        return 1
    fi
}

has_nvidia_gpu() {
    detect_nvidia_gpu >/dev/null 2>&1
}

detect_ram_gb() {
    if [[ -f /proc/meminfo ]]; then
        local mem_kb
        mem_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        echo $((mem_kb / 1024 / 1024))
    else
        echo "0"
    fi
}

detect_disk_free_gb() {
    if [[ -d / ]]; then
        df -BG / 2>/dev/null | tail -1 | awk '{print $4}' | tr -d 'G'
    else
        echo "0"
    fi
}

get_recommended_swap_size() {
    local ram_gb
    ram_gb=$(detect_ram_gb)
    if [[ "$ram_gb" -lt 8 ]]; then
        echo "8G"
    elif [[ "$ram_gb" -lt 32 ]]; then
        echo "16G"
    elif [[ "$ram_gb" -lt 64 ]]; then
        echo "32G"
    else
        echo "64G"
    fi
}

require_ubuntu() {
    detect_os
    if [[ "$DISTRO" != "ubuntu" ]]; then
        print_error "This script requires Ubuntu. Detected: $DISTRO"
        exit 1
    fi
}

require_root() {
    if [[ $EUID -ne 0 ]] && [[ "$DRY_RUN" -ne 1 ]]; then
        print_error "This operation requires root. Run with sudo or as root."
        exit 1
    fi
}

check_command() {
    command -v "$1" >/dev/null 2>&1
}

url_exists() {
    curl -s -o /dev/null -w "%{http_code}" -L "$1" | grep -q "200"
}
