#!/usr/bin/env bash
# dashboard.sh - install & open Headlamp, a clean web GUI for the cluster.
#   make dashboard   -> installs Headlamp + an admin login (run once)
#   make ui          -> prints your login token and opens the UI via port-forward
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_cluster

ACTION="${1:-open}"
NS="kube-system"
PORT="${HEADLAMP_PORT:-8080}"

install_headlamp() {
  title "Installing Headlamp (web GUI for your cluster)"
  command -v helm >/dev/null 2>&1 || die "Helm not found. Run 'make stack' first (it installs helm)."
  helm repo add headlamp https://kubernetes-sigs.github.io/headlamp/ >/dev/null 2>&1 || true
  helm repo update >/dev/null
  local vflag=""; [[ -n "${DASHBOARD_VERSION:-}" ]] && vflag="--version ${DASHBOARD_VERSION}"
  # shellcheck disable=SC2086
  helm upgrade --install headlamp headlamp/headlamp -n "$NS" $vflag --wait --timeout 5m
  info "Creating admin login..."
  kc apply -f "${REPO_ROOT}/manifests/dashboard/headlamp-admin.yaml"
  ok "Headlamp installed."
  echo "Open it any time with:  make ui"
}

open_headlamp() {
  kc -n "$NS" get deploy headlamp >/dev/null 2>&1 || \
    die "Headlamp isn't installed yet. Run:  make dashboard"
  title "Headlamp login"
  # Wait for the token to be populated, then print it.
  local token=""
  for _ in $(seq 1 10); do
    token="$(kc -n "$NS" get secret headlamp-admin-token -o jsonpath='{.data.token}' 2>/dev/null | base64 -d 2>/dev/null || true)"
    [[ -n "$token" ]] && break; sleep 1
  done
  [[ -n "$token" ]] || die "Couldn't read the login token. Try: kubectl -n $NS get secret headlamp-admin-token -o yaml"
  echo "1) When the browser opens, choose 'Token' auth and paste this:"
  echo
  echo "${C_BLD}${token}${C_RST}"
  echo
  echo "2) Leaving this running serves the UI. Ctrl-C to stop."
  hr
  ok "Opening http://localhost:${PORT}  (forwarding to the Headlamp service)..."
  command -v xdg-open >/dev/null 2>&1 && (sleep 2; xdg-open "http://localhost:${PORT}" >/dev/null 2>&1 &) || true
  command -v open     >/dev/null 2>&1 && (sleep 2; open "http://localhost:${PORT}" >/dev/null 2>&1 &) || true
  kc -n "$NS" port-forward svc/headlamp "${PORT}:80"
}

case "$ACTION" in
  install) install_headlamp ;;
  open)    open_headlamp ;;
  *) die "Usage: dashboard.sh [install|open]" ;;
esac
