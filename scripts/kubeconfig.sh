#!/usr/bin/env bash
# kubeconfig.sh - copy the k3s kubeconfig to ~/.kube/config so plain 'kubectl' works.
# Run this on the control-plane node after install.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

SRC="/etc/rancher/k3s/k3s.yaml"
maybe_sudo test -r "$SRC" || die "$SRC not found. Run this on the control-plane node."

mkdir -p "$HOME/.kube"
maybe_sudo cat "$SRC" | sed "s/127.0.0.1/${SERVER_HOST}/" > "$HOME/.kube/config"
chmod 600 "$HOME/.kube/config"
ok "Wrote $HOME/.kube/config (API server -> ${SERVER_HOST})"
echo "Test it:  kubectl get nodes"
echo "To use from your LAPTOP, copy this file there and keep the same server IP."
