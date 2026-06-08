#!/usr/bin/env bash
# fix-cni.sh — recover a node stuck NotReady with "cni plugin not initialized".
# Run on the affected machine:  sudo ./scripts/fix-cni.sh
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

is_root || die "Run with sudo:  sudo ./scripts/fix-cni.sh"

title "Fixing k3s CNI (NotReady / cni plugin not initialized)"

CNI_SYNC="${REPO_ROOT}/scripts/k3s-cni-sync.sh"
[[ -f "$CNI_SYNC" ]] || die "Missing $CNI_SYNC"

CNI_SYNC_TIMEOUT=180 bash "$CNI_SYNC" post-join

if command -v k3s >/dev/null 2>&1 && k3s kubectl get nodes >/dev/null 2>&1; then
  info "Waiting for this node to report Ready (up to 3 min)..."
  for _ in $(seq 1 36); do
    if k3s kubectl get node -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -q '^True$'; then
      ok "Node is Ready."
      k3s kubectl get nodes -o wide
      exit 0
    fi
    sleep 5
  done
  warn "Still NotReady — check: journalctl -u k3s-agent -n 50"
fi

ok "CNI synced and k3s restarted. From a controller: kubectl get nodes"
