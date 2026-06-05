#!/usr/bin/env bash
# remove-node.sh - RUN ON A SERVER. Gracefully evict + remove a node, no downtime.
# Usage: make remove-node NODE=<node-name>
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_cluster

NODE="${NODE:-${1:-}}"
[[ -n "$NODE" ]] || die "Tell me which node:  make remove-node NODE=<name>   (see 'make status')"
kc get node "$NODE" >/dev/null 2>&1 || die "Node '$NODE' not found. Check 'make status'."

title "Removing node: $NODE"
info "Workloads on this node will reschedule onto other matching GPUs first."
confirm "Cordon + drain + delete '$NODE'?" || die "Aborted."

info "1/3 Cordoning (stop new pods landing here)..."
kc cordon "$NODE"

info "2/3 Draining (evict running pods gracefully)..."
kc drain "$NODE" --ignore-daemonsets --delete-emptydir-data --timeout=120s || \
  warn "Drain hit the timeout. Some pods may need a PodDisruptionBudget review."

info "3/3 Deleting node object from the cluster..."
kc delete node "$NODE"

hr
ok "Node '$NODE' removed from the cluster."
echo "Finally, ON THAT PHYSICAL MACHINE, uninstall k3s to clean up:"
echo "  worker:  /usr/local/bin/k3s-agent-uninstall.sh"
echo "  server:  /usr/local/bin/k3s-uninstall.sh"
