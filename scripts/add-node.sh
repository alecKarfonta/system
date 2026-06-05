#!/usr/bin/env bash
# add-node.sh - RUN ON A SERVER. Prints the exact command to run on a new machine.
# This is the "easy add" button: copy the printed line, paste it on the new box.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

TOKEN_FILE="/var/lib/rancher/k3s/server/node-token"
[[ -r "$TOKEN_FILE" ]] || maybe_sudo test -r "$TOKEN_FILE" || \
  die "Can't read $TOKEN_FILE. Run this on a control-plane node."
TOKEN="$(maybe_sudo cat "$TOKEN_FILE")"

ROLE="${1:-worker}"
title "Add a node to cluster '${CLUSTER_NAME}'"
echo "On the NEW machine: clone this repo, copy your cluster.env, then run ONE of:"
echo

case "$ROLE" in
  worker)
    echo "  ${C_BLD}# GPU worker (most common):${C_RST}"
    echo "  JOIN_TOKEN='${TOKEN}' make agent"
    ;;
  server)
    echo "  ${C_BLD}# Additional control-plane (HA, use an odd total count):${C_RST}"
    echo "  JOIN_TOKEN='${TOKEN}' make join-server"
    ;;
  *) die "Unknown role '$ROLE'. Use 'worker' or 'server'." ;;
esac

echo
echo "${C_DIM}Don't want to clone the repo on the new box? Raw one-liner:${C_RST}"
if [[ "$ROLE" == "worker" ]]; then
  echo "  curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL='${K3S_CHANNEL}' \\"
  echo "    K3S_URL='https://${SERVER_HOST}:${SERVER_PORT}' K3S_TOKEN='${TOKEN}' \\"
  echo "    sh -s - agent --node-label node-role.homelab/gpu-worker=true"
else
  echo "  curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL='${K3S_CHANNEL}' \\"
  echo "    K3S_TOKEN='${TOKEN}' \\"
  echo "    sh -s - server --server 'https://${SERVER_HOST}:${SERVER_PORT}' \\"
  echo "    --node-label node-role.homelab/control-plane=true"
fi
hr
warn "The token is a cluster credential. Don't paste it into chat logs or commits."
