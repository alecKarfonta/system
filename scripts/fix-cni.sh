#!/usr/bin/env bash
# fix-cni.sh - recover from "cni plugin not initialized" / node stuck NotReady.
# Run on the control-plane node with sudo available.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

is_root || die "Run with sudo:  sudo ./scripts/fix-cni.sh"

K3S_CNI="/var/lib/rancher/k3s/agent/etc/cni/net.d"
ETC_CNI="/etc/cni/net.d"

title "Fixing k3s CNI (NotReady / cni plugin not initialized)"

if [[ ! -d "$K3S_CNI" ]]; then
  die "k3s CNI dir missing ($K3S_CNI). Is k3s installed on this node?"
fi

info "Step 1: restore CNI config into /etc/cni/net.d"
mkdir -p "$ETC_CNI"
shopt -s nullglob
files=("$K3S_CNI"/*)
if [[ ${#files[@]} -eq 0 ]]; then
  die "No CNI configs in $K3S_CNI — try: sudo systemctl restart k3s and re-run"
fi
cp -af "${files[@]}" "$ETC_CNI/"
ok "Copied ${#files[@]} file(s) to $ETC_CNI"

K3S_BIN="/var/lib/rancher/k3s/data/current/bin"
OPT_BIN="/opt/cni/bin"
info "Step 2: link CNI binaries into $OPT_BIN"
if [[ -d "$K3S_BIN" ]]; then
  mkdir -p "$OPT_BIN"
  ln -sf "$K3S_BIN"/* "$OPT_BIN"/
  ok "Linked CNI plugins from k3s ($K3S_BIN)"
else
  warn "$K3S_BIN not found — skipping binary link"
fi

info "Step 3: restart k3s"
if systemctl is-active --quiet k3s 2>/dev/null; then
  systemctl restart k3s
elif systemctl is-active --quiet k3s-agent 2>/dev/null; then
  systemctl restart k3s-agent
else
  systemctl restart k3s 2>/dev/null || systemctl restart k3s-agent
fi
sleep 5

K3S_KUBECTL="k3s kubectl"
if ! command -v k3s >/dev/null 2>&1 || ! k3s kubectl get nodes >/dev/null 2>&1; then
  K3S_KUBECTL="kubectl"
fi

if command -v k3s >/dev/null 2>&1 || command -v kubectl >/dev/null 2>&1; then
  info "Step 4: waiting for node Ready (up to 3 min)..."
  for i in $(seq 1 36); do
    if $K3S_KUBECTL get node -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' 2>/dev/null | grep -q '=True'; then
      ok "Node is Ready."
      $K3S_KUBECTL get nodes -o wide
      exit 0
    fi
    sleep 5
  done
  warn "Still NotReady. Check: journalctl -u k3s -n 50"
  warn "Nuclear option: sudo k3s-killall.sh && sudo ip link delete cni0 flannel.1 2>/dev/null; sudo systemctl start k3s"
  exit 1
fi

ok "k3s restarted. Run: kubectl get nodes"
