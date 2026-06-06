#!/usr/bin/env bash
# cockpit.sh - install/open/demo the Fleet Cockpit GUI.
#   make cockpit       -> install/update it in the cluster
#   make cockpit-ui    -> open via port-forward (also reachable at :30880 on any node)
#   make cockpit-demo  -> run locally with fake data to preview the UI
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ACTION="${1:-open}"
PORT="${COCKPIT_PORT:-8090}"

case "$ACTION" in
  install)
    require_cluster
    title "Installing Fleet Cockpit"
    kc create namespace cockpit --dry-run=client -o yaml | kc apply -f - >/dev/null
    kc -n cockpit create configmap cockpit-code \
        --from-file="${REPO_ROOT}/cockpit/app.py" \
        --from-file="${REPO_ROOT}/cockpit/index.html" \
        --dry-run=client -o yaml | kc apply -f - >/dev/null
    kc apply -f "${REPO_ROOT}/manifests/cockpit/cockpit.yaml" >/dev/null
    kc -n cockpit rollout restart deploy/cockpit >/dev/null 2>&1 || true
    ok "Cockpit deployed."
    echo "Open it:   make cockpit-ui"
    echo "Or browse: http://<any-node-ip>:30880   (stable LAN URL, no port-forward needed)"
    ;;
  open)
    require_cluster
    kc -n cockpit get deploy cockpit >/dev/null 2>&1 || die "Not installed yet. Run: make cockpit"
    ok "Opening http://localhost:${PORT} ..."
    command -v xdg-open >/dev/null 2>&1 && (sleep 2; xdg-open "http://localhost:${PORT}" >/dev/null 2>&1 &) || true
    command -v open     >/dev/null 2>&1 && (sleep 2; open "http://localhost:${PORT}" >/dev/null 2>&1 &) || true
    kc -n cockpit port-forward svc/cockpit "${PORT}:80"
    ;;
  demo)
    title "Fleet Cockpit — local demo with fake data (Ctrl-C to stop)"
    HOMELAB_DEMO=1 PORT="${PORT}" python3 "${REPO_ROOT}/cockpit/app.py"
    ;;
  *) die "Usage: cockpit.sh [install|open|demo]" ;;
esac
