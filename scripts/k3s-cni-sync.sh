#!/usr/bin/env bash
# k3s-cni-sync.sh — copy k3s agent CNI config where kubelet/containerd expect it.
# Fixes nodes stuck NotReady with "cni plugin not initialized" when /etc/cni/net.d is empty.
set -euo pipefail

K3S_CNI="/var/lib/rancher/k3s/agent/etc/cni/net.d"
ETC_CNI="/etc/cni/net.d"
K3S_BIN="/var/lib/rancher/k3s/data/current/bin"
OPT_BIN="/opt/cni/bin"
SYNC_DEST="/usr/local/bin/k3s-cni-sync.sh"

sync_k3s_cni() {
  [[ -d "$K3S_CNI" ]] || return 1
  shopt -s nullglob
  local files=("$K3S_CNI"/*)
  [[ ${#files[@]} -gt 0 ]] || return 1
  mkdir -p "$ETC_CNI" "$OPT_BIN"
  cp -af "${files[@]}" "$ETC_CNI/"
  if [[ -d "$K3S_BIN" ]]; then
    ln -sf "$K3S_BIN"/* "$OPT_BIN"/ 2>/dev/null || true
  fi
  return 0
}

wait_k3s_cni() {
  local timeout="${1:-120}" end=$((SECONDS + timeout))
  while (( SECONDS < end )); do
    sync_k3s_cni && return 0
    sleep 2
  done
  return 1
}

_k3s_unit() {
  systemctl cat k3s-agent.service &>/dev/null && echo k3s-agent && return
  systemctl cat k3s.service &>/dev/null && echo k3s && return
  return 1
}

install_k3s_cni_hook() {
  local src="${BASH_SOURCE[0]}"
  [[ -f "$src" ]] && install -m 755 "$src" "$SYNC_DEST"
  local svc
  svc="$(_k3s_unit)" || return 0
  mkdir -p "/etc/systemd/system/${svc}.service.d"
  cat > "/etc/systemd/system/${svc}.service.d/cni-sync.conf" << 'EOF'
[Service]
ExecStartPost=-/usr/local/bin/k3s-cni-sync.sh sync
EOF
  systemctl daemon-reload
}

post_join_cni() {
  install_k3s_cni_hook
  wait_k3s_cni "${CNI_SYNC_TIMEOUT:-120}" || {
    echo "warn: CNI config not ready yet — systemd hook will retry on next k3s start" >&2
    return 0
  }
  local svc
  svc="$(_k3s_unit)" || return 0
  systemctl restart "$svc" || true
  sleep 5
  wait_k3s_cni 60 || true
}

usage() {
  echo "Usage: $0 {sync|wait [sec]|install-hook|post-join}" >&2
  exit 1
}

cmd="${1:-sync}"
case "$cmd" in
  sync)     wait_k3s_cni "${CNI_SYNC_TIMEOUT:-30}" ;;
  wait)     wait_k3s_cni "${2:-120}" ;;
  install-hook) install_k3s_cni_hook ;;
  post-join) post_join_cni ;;
  *) usage ;;
esac
