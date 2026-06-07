#!/usr/bin/env bash
# join-server.sh - add an ADDITIONAL control-plane node for HA (run on that machine).
# Run 'make add-node' on the first server to get the token, then run this here.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

: "${JOIN_TOKEN:?Set JOIN_TOKEN (get it from 'make add-node' on the first server).}"

title "Joining $(hostname) as an additional control-plane (HA) node"
warn "For a healthy etcd quorum, run an ODD number of servers (3 is the sweet spot)."

EXTRA_ARGS=( "--server" "https://${SERVER_HOST}:${SERVER_PORT}"
             "--node-label" "node-role.homelab/control-plane=true" )
[[ "${TAILSCALE_ENABLED}" == "1" ]] && \
  EXTRA_ARGS+=( "--vpn-auth" "name=tailscale,joinKey=${TAILSCALE_AUTHKEY}" )

confirm "Join cluster at ${SERVER_HOST}:${SERVER_PORT}?" || die "Aborted."

# shellcheck source=lib/longhorn-node-prep.sh
source "${REPO_ROOT}/scripts/lib/longhorn-node-prep.sh"
prep_longhorn_node_host

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" \
  K3S_TOKEN="${JOIN_TOKEN}" \
  sh -s - server "${EXTRA_ARGS[@]}"

# shellcheck source=lib/cni-sync.sh
source "${REPO_ROOT}/scripts/lib/cni-sync.sh"
run_post_join_cni

ok "Joined as control-plane. Check with: make status"
