#!/usr/bin/env bash
# cni-sync.sh — helpers for install/join scripts (sources common.sh first).

CNI_SYNC_SCRIPT="${REPO_ROOT}/scripts/k3s-cni-sync.sh"

run_post_join_cni() {
  [[ -f "$CNI_SYNC_SCRIPT" ]] || die "Missing $CNI_SYNC_SCRIPT"
  info "Syncing k3s CNI into /etc/cni/net.d (prevents NotReady / cni plugin not initialized)"
  CNI_SYNC_TIMEOUT="${CNI_SYNC_TIMEOUT:-120}" maybe_sudo bash "$CNI_SYNC_SCRIPT" post-join
  ok "CNI sync complete (systemd hook installed for future restarts)"
}
