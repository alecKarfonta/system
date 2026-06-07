#!/usr/bin/env bash
# install-server.sh - install the FIRST control-plane node (run on that machine).
# Creates an HA-ready cluster with embedded etcd (--cluster-init).
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

title "Installing k3s control-plane (first server) for cluster '${CLUSTER_NAME}'"

if command -v k3s >/dev/null 2>&1 && systemctl is-active --quiet k3s 2>/dev/null; then
  warn "k3s server already appears to be running on $(hostname)."
  confirm "Re-run the installer anyway? (usually you don't need to)" || die "Nothing to do."
fi

EXTRA_ARGS=( "--cluster-init" "--write-kubeconfig-mode" "644"
             "--node-label" "node-role.homelab/control-plane=true" )
[[ "${K3S_DISABLE_TRAEFIK}"  == "1" ]] && EXTRA_ARGS+=( "--disable" "traefik" )
[[ "${K3S_DISABLE_SERVICELB}" == "1" ]] && EXTRA_ARGS+=( "--disable" "servicelb" )

if [[ "${TAILSCALE_ENABLED}" == "1" ]]; then
  [[ -n "${TAILSCALE_AUTHKEY}" ]] || die "TAILSCALE_ENABLED=1 but TAILSCALE_AUTHKEY is empty."
  command -v tailscale >/dev/null 2>&1 || die "Install Tailscale first: https://tailscale.com/download"
  EXTRA_ARGS+=( "--vpn-auth" "name=tailscale,joinKey=${TAILSCALE_AUTHKEY}" )
  info "Tailscale VPN networking enabled."
fi

info "k3s flags: ${EXTRA_ARGS[*]}"
confirm "Proceed with install on $(hostname)?" || die "Aborted."

# shellcheck source=lib/longhorn-node-prep.sh
source "${REPO_ROOT}/scripts/lib/longhorn-node-prep.sh"
prep_longhorn_node_host

curl -sfL https://get.k3s.io | \
  INSTALL_K3S_CHANNEL="${K3S_CHANNEL}" \
  sh -s - server "${EXTRA_ARGS[@]}"

# shellcheck source=lib/cni-sync.sh
source "${REPO_ROOT}/scripts/lib/cni-sync.sh"
run_post_join_cni

info "Waiting for the node to become Ready..."
for i in $(seq 1 30); do
  if maybe_sudo k3s kubectl get node >/dev/null 2>&1; then break; fi
  sleep 2
done
maybe_sudo k3s kubectl get nodes -o wide || true

hr
ok "Control-plane installed."
echo "Next steps:"
echo "  1) Set up your kubeconfig:      make kubeconfig"
echo "  2) Add more nodes:              make add-node      (prints the join command)"
echo "  3) Install the GPU stack:       make stack"
echo
echo "Node-join token (keep it secret) lives at: /var/lib/rancher/k3s/server/node-token"
