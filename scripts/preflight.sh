#!/usr/bin/env bash
# preflight.sh - sanity-check a machine BEFORE installing k3s on it.
# Run this on every machine you intend to add (server or GPU worker).
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

title "Preflight checks for: $(hostname)"
PROBLEMS=0
note() { warn "$*"; PROBLEMS=$((PROBLEMS+1)); }

# OS
if [[ -r /etc/os-release ]]; then
  . /etc/os-release
  info "OS: ${PRETTY_NAME:-unknown}"
  case "${ID:-}" in
    ubuntu|debian) ok "Supported base OS" ;;
    *) note "Tested on Ubuntu/Debian. '${ID:-?}' may work but is untested." ;;
  esac
else
  note "Could not read /etc/os-release."
fi

# Architecture
info "Arch: $(uname -m)"

# Memory & disk
mem_gb=$(awk '/MemTotal/ {printf "%.1f", $2/1024/1024}' /proc/meminfo)
info "RAM: ${mem_gb} GiB"
root_free=$(df -BG --output=avail / | tail -1 | tr -dc '0-9')
info "Free disk on /: ${root_free} GiB"
[[ "${root_free:-0}" -lt 20 ]] && note "Less than 20 GiB free on /. k3s + images want more."

# Required tools
for c in curl; do require_cmd "$c"; done
ok "curl present"

# python3 powers the rich 'make status' view (optional, has a fallback)
if command -v python3 >/dev/null 2>&1; then
  ok "python3 present"
else
  note "python3 not found. 'make status' will use a basic view. Install with: sudo apt install -y python3"
fi

# NVIDIA GPU present?
if command -v lspci >/dev/null 2>&1 && lspci | grep -qi nvidia; then
  gpu_lines=$(lspci | grep -i nvidia | grep -iE 'vga|3d|display' || true)
  ok "NVIDIA GPU detected:"
  echo "$gpu_lines" | sed 's/^/      /'
else
  note "No NVIDIA GPU detected via lspci. (Fine for a control-plane-only node.)"
fi

# Driver present?
if command -v nvidia-smi >/dev/null 2>&1; then
  drv=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader 2>/dev/null | head -1 || echo '?')
  ok "NVIDIA driver installed (version ${drv})"
else
  note "nvidia-smi not found. If this is a GPU node, either install the driver
       (recommended for consumer cards) or set GPU_OPERATOR_MANAGES_DRIVER=1."
fi

# Longhorn storage prerequisites
# shellcheck source=lib/longhorn-node-prep.sh
source "${REPO_ROOT}/scripts/lib/longhorn-node-prep.sh"
check_longhorn_host_preflight

# Swap (k3s tolerates it, but flag for awareness)
if swapon --show 2>/dev/null | grep -q .; then
  info "Swap is on (k3s works fine with swap on)."
fi

# Time sync (cluster certs hate clock skew)
if command -v timedatectl >/dev/null 2>&1; then
  if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
    ok "Clock is NTP-synchronized"
  else
    note "Clock not NTP-synced. Run: sudo timedatectl set-ntp true"
  fi
fi

hr
if [[ "$PROBLEMS" -eq 0 ]]; then
  ok "All clear. This machine is ready."
else
  warn "$PROBLEMS item(s) to look at above. None are necessarily fatal — read and decide."
fi
