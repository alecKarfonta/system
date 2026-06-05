#!/usr/bin/env bash
# uninstall.sh - remove k3s from THE MACHINE THIS RUNS ON. Destructive.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
warn "This removes k3s and ALL its data from $(hostname)."
warn "If this node is still part of a cluster, run 'make remove-node NODE=$(hostname)'"
warn "from a server FIRST so the cluster forgets it cleanly."
confirm "Really uninstall k3s from $(hostname)?" || die "Aborted."
if [[ -x /usr/local/bin/k3s-uninstall.sh ]]; then
  maybe_sudo /usr/local/bin/k3s-uninstall.sh; ok "Server uninstalled."
elif [[ -x /usr/local/bin/k3s-agent-uninstall.sh ]]; then
  maybe_sudo /usr/local/bin/k3s-agent-uninstall.sh; ok "Agent uninstalled."
else
  die "No k3s uninstall script found. Is k3s installed here?"
fi
