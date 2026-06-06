#!/usr/bin/env bash
# install-driver-node.sh — SSH to a cluster node and install the NVIDIA host driver.
# Usage:
#   make install-driver-node NODE=node-4 USER=alec
#   make install-driver-node HOST=192.168.1.4 USER=alec
#   ASSUME_YES=1 make install-driver-node NODE=node-4   # skip confirm + auto-reboot
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_cluster
load_env

NODE="${NODE:-}"
HOST="${HOST:-}"
USER="${USER:-${COCKPIT_SSH_USER:-root}}"
PORT="${PORT:-22}"
REBOOT="${REBOOT:-ask}"

[[ -n "$NODE" || -n "$HOST" ]] || die "Usage: make install-driver-node NODE=name  or  HOST=ip [USER=alec]"

if [[ -n "$NODE" && -z "$HOST" ]]; then
  HOST="$(kc get node "$NODE" -o jsonpath='{.status.addresses[?(@.type=="InternalIP")].address}' 2>/dev/null || true)"
  [[ -n "$HOST" ]] || die "Could not resolve InternalIP for node $NODE"
fi

title "Install NVIDIA driver on ${USER}@${HOST}${NODE:+ ($NODE)}"

if [[ "${GPU_OPERATOR_MANAGES_DRIVER:-0}" == "1" ]]; then
  die "GPU_OPERATOR_MANAGES_DRIVER=1 — operator installs drivers. Re-run make stack or set to 0."
fi

SSH_OPTS=(-o ConnectTimeout=20 -o StrictHostKeyChecking=accept-new)
SSH=(ssh "${SSH_OPTS[@]}" -p "$PORT" "${USER}@${HOST}")

confirm "SSH to ${HOST} and install NVIDIA driver?" || die "Aborted."

REMOTE_ENV="GPU_OPERATOR_MANAGES_DRIVER=${GPU_OPERATOR_MANAGES_DRIVER:-0}"
REMOTE_ENV+=" NVIDIA_DRIVER_PACKAGE=${NVIDIA_DRIVER_PACKAGE:-}"
REMOTE_ENV+=" NVIDIA_DRIVER_FLAVOR=${NVIDIA_DRIVER_FLAVOR:-open}"

info "Running driver install script on ${HOST}…"
RC=0
"${SSH[@]}" "sudo env ${REMOTE_ENV} bash -s" < "${REPO_ROOT}/scripts/install-nvidia-driver.sh" || RC=$?

if [[ "$RC" -eq 0 ]]; then
  ok "Driver installed and nvidia-smi works on ${HOST}."
  if [[ -n "$NODE" ]]; then
    info "Applying homelab GPU labels…"
    "${REPO_ROOT}/scripts/label-gpus.sh"
  fi
  exit 0
fi

if [[ "$RC" -eq 2 ]]; then
  warn "Reboot required on ${HOST}."
  if [[ "$REBOOT" == "1" || "${ASSUME_YES:-}" == "1" ]]; then
    info "Rebooting ${HOST}…"
    "${SSH[@]}" "sudo reboot" || true
    if [[ -n "$NODE" ]]; then
      info "Waiting for ${NODE} to become Ready…"
      kc wait --for=condition=Ready "node/${NODE}" --timeout=600s
      ok "Node ${NODE} is Ready — run make label-gpus"
    fi
  else
    echo "  Reboot the node, then: make label-gpus"
  fi
  exit 0
fi

die "Driver install failed (exit ${RC})."
