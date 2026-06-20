#!/usr/bin/env bash
# install-nvidia-driver.sh — install the host NVIDIA driver (consumer-GPU path).
# Used locally (make install-driver), via SSH (make install-driver-node), and
# from Fleet Command remote driver jobs.
#
# Exit codes:
#   0 — driver working (nvidia-smi OK)
#   2 — packages installed, reboot required
#   1 — error / GPU Operator manages drivers
#
# Env (from config/cluster.env):
#   GPU_OPERATOR_MANAGES_DRIVER  0=host install (default), 1=refuse (operator owns it)
#   NVIDIA_DRIVER_PACKAGE        optional apt package (e.g. nvidia-driver-575-open)
#   NVIDIA_DRIVER_FLAVOR         "open" tries open drivers for new consumer GPUs
set -euo pipefail

GPU_OPERATOR_MANAGES_DRIVER="${GPU_OPERATOR_MANAGES_DRIVER:-0}"
NVIDIA_DRIVER_PACKAGE="${NVIDIA_DRIVER_PACKAGE:-}"
NVIDIA_DRIVER_FLAVOR="${NVIDIA_DRIVER_FLAVOR:-open}"

if [[ "${GPU_OPERATOR_MANAGES_DRIVER}" == "1" ]]; then
  echo "GPU Operator manages drivers — set GPU_OPERATOR_MANAGES_DRIVER=0 for host install."
  exit 1
fi

nvidia_ok() {
  command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1
}

if nvidia_ok; then
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1
  echo "DRIVER_OK"
  exit 0
fi

if ! command -v lspci >/dev/null 2>&1 || ! lspci -Dnnd 10de: 2>/dev/null | grep -q '0300'; then
  echo "No NVIDIA GPU detected on PCI bus."
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null 2>&1; then
  apt-get update -qq
  apt-get install -y -qq ubuntu-drivers-common pciutils curl ca-certificates
else
  echo "apt-get not found — Ubuntu/Debian required."
  exit 1
fi

install_pkg() {
  local pkg="$1"
  echo "Installing ${pkg}…"
  apt-get install -y -qq "$pkg"
}

if [[ -n "${NVIDIA_DRIVER_PACKAGE}" ]]; then
  install_pkg "${NVIDIA_DRIVER_PACKAGE}"
elif [[ "${NVIDIA_DRIVER_FLAVOR}" == "open" ]]; then
  # RTX 50xx / Blackwell — open kernel modules (575+)
  if lspci -Dnnd 10de: 2>/dev/null | grep -qE '10de:2[0-9a-f]{3}'; then
    for pkg in nvidia-driver-575-open nvidia-driver-570-open; do
      if apt-cache show "$pkg" &>/dev/null; then
        install_pkg "$pkg"
        break
      fi
    done
  fi
fi

if ! nvidia_ok; then
  if command -v ubuntu-drivers >/dev/null 2>&1; then
    ubuntu-drivers install --gpgpu -y 2>/dev/null || ubuntu-drivers install -y
  else
    echo "ubuntu-drivers not available."
    exit 1
  fi
fi

if nvidia_ok; then
  nvidia-smi --query-gpu=name,driver_version --format=csv,noheader | head -1
  echo "DRIVER_OK"
  exit 0
fi

if [[ -f /var/run/reboot-required ]]; then
  echo "REBOOT_REQUIRED"
  exit 2
fi

echo "Driver packages installed but nvidia-smi still unavailable — reboot required."
exit 2
