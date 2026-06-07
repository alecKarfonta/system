#!/usr/bin/env bash
# install-agent.sh - add a GPU WORKER node (run on the new machine).
# Run 'make add-node' on the server first to get the token.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

: "${JOIN_TOKEN:?Set JOIN_TOKEN (get it from 'make add-node' on a server).}"

title "Joining $(hostname) as a GPU worker"

if command -v k3s >/dev/null 2>&1 && systemctl is-active --quiet k3s-agent 2>/dev/null; then
  warn "A k3s agent already appears to be running on $(hostname)."
  confirm "Re-run the installer anyway?" || die "Nothing to do."
fi

EXTRA_ARGS=( "--node-label" "node-role.homelab/gpu-worker=true" )
[[ "${TAILSCALE_ENABLED}" == "1" ]] && \
  EXTRA_ARGS+=( "--vpn-auth" "name=tailscale,joinKey=${TAILSCALE_AUTHKEY}" )

confirm "Join cluster at ${SERVER_HOST}:${SERVER_PORT} as a worker?" || die "Aborted."

# shellcheck source=lib/longhorn-node-prep.sh
source "${REPO_ROOT}/scripts/lib/longhorn-node-prep.sh"
prep_longhorn_node_host

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" \
  K3S_URL="https://${SERVER_HOST}:${SERVER_PORT}" \
  K3S_TOKEN="${JOIN_TOKEN}" \
  sh -s - agent "${EXTRA_ARGS[@]}"

# shellcheck source=lib/cni-sync.sh
source "${REPO_ROOT}/scripts/lib/cni-sync.sh"
run_post_join_cni

hr
ok "Worker joined."
echo "On a server (or your laptop) run:"
echo "  make label-gpus     # auto-tag this node's GPUs by tier"
echo "  make status         # confirm it shows up with its GPUs"
