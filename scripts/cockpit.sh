#!/usr/bin/env bash
# cockpit.sh - install/open/demo the Fleet Command GUI.
#   make cockpit       -> install/update it in the cluster
#   make cockpit-ui    -> open via port-forward (also reachable at :30880 on any node)
#   make cockpit-demo  -> run locally with fake data to preview the UI
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

ACTION="${1:-open}"
PORT="${COCKPIT_PORT:-8090}"

case "$ACTION" in
  install)
    require_cluster
    [[ -f "${REPO_ROOT}/config/cluster.env" ]] && load_env "${REPO_ROOT}/config/cluster.env"
    title "Installing Fleet Command"
    kc create namespace cockpit --dry-run=client -o yaml | kc apply -f - >/dev/null
    APPS_JSON="$(python3 <<PY
import json, subprocess, sys
from pathlib import Path
import yaml
root = Path("${REPO_ROOT}")
apps = []
lib = root / "scripts/lib/app_config.py"
for f in sorted((root / "apps").glob("*.yaml")):
    name = f.stem
    reg = yaml.safe_load(f.read_text()) or {}
    entry = {"name": name, "repo": reg.get("repo", "")}
    if lib.is_file():
        r = subprocess.run([sys.executable, str(lib), name, "export"],
                           capture_output=True, text=True)
        if r.returncode == 0:
            cfg = json.loads(r.stdout)
            entry["namespace"] = cfg.get("namespace", "")
            entry["deployment"] = cfg.get("deployment", "")
    apps.append(entry)
print(json.dumps(apps))
PY
)"
    kc -n cockpit create configmap cockpit-code \
        --from-file="${REPO_ROOT}/cockpit/app.py" \
        --from-file="${REPO_ROOT}/cockpit/index.html" \
        --from-file=install-nvidia-driver.sh="${REPO_ROOT}/scripts/install-nvidia-driver.sh" \
        --from-file=k3s-cni-sync.sh="${REPO_ROOT}/scripts/k3s-cni-sync.sh" \
        --from-file=apps.json=<(echo "${APPS_JSON}") \
        --dry-run=client -o yaml | kc apply -f - >/dev/null
    # shellcheck source=lib/join-token.sh
    source "${REPO_ROOT}/scripts/lib/join-token.sh"
    TOKEN=""
    if TOKEN="$(fetch_join_token 2>/dev/null)" && [[ -n "${TOKEN:-}" ]]; then
      : # fetched
    else
      TOKEN=""
    fi
    if [[ -z "${SERVER_HOST:-}" ]]; then
      warn "SERVER_HOST not set in config/cluster.env — cannot configure Add Node."
    elif [[ -n "${TOKEN:-}" ]]; then
      kc -n cockpit create secret generic cockpit-join \
          --from-literal=token="${TOKEN}" \
          --from-literal=server_host="${SERVER_HOST}" \
          --from-literal=server_port="${SERVER_PORT:-6443}" \
          --from-literal=k3s_channel="${K3S_CHANNEL:-stable}" \
          --from-literal=gpu_operator_manages_driver="${GPU_OPERATOR_MANAGES_DRIVER:-0}" \
          --from-literal=nvidia_driver_package="${NVIDIA_DRIVER_PACKAGE:-}" \
          --from-literal=nvidia_driver_flavor="${NVIDIA_DRIVER_FLAVOR:-open}" \
          --from-literal=system_root="${REPO_ROOT}" \
          --dry-run=client -o yaml | kc apply -f - >/dev/null
      ok "Join secret created (Add Node enabled in Fleet Command)."
    else
      warn "Could not fetch k3s join token."
      echo "  Fix: set JOIN_TOKEN in config/cluster.env (from 'make add-node' on sonic), then re-run make cockpit"
      echo "  Or run make cockpit from a machine with kubectl access (auto-fetches via control-plane pod)."
    fi
    SSH_KEY="${COCKPIT_SSH_KEY:-}"
    for cand in "${SSH_KEY}" "${HOME}/.ssh/id_ed25519" "${HOME}/.ssh/id_rsa"; do
      [[ -n "${cand}" && -f "${cand}" ]] && SSH_KEY="${cand}" && break
    done
    if [[ -n "${SSH_KEY}" && -f "${SSH_KEY}" ]]; then
      SSH_FIELD="id_ed25519"
      [[ "${SSH_KEY}" == *"id_rsa"* ]] && SSH_FIELD="id_rsa"
      kc -n cockpit create secret generic cockpit-ssh \
          --from-file="${SSH_FIELD}=${SSH_KEY}" \
          --dry-run=client -o yaml | kc apply -f - >/dev/null
      ok "SSH key saved for remote Add Node (from ${SSH_KEY})."
    else
      warn "No SSH key found — paste a key in Fleet Command or set COCKPIT_SSH_KEY in cluster.env."
    fi
    kc apply -f "${REPO_ROOT}/manifests/cockpit/cockpit.yaml" >/dev/null
    kc -n cockpit rollout restart deploy/cockpit >/dev/null 2>&1 || true
    kc -n cockpit rollout status deploy/cockpit --timeout=120s >/dev/null 2>&1 || \
      warn "Fleet Command rollout slow — if UI looks stale, run: kubectl -n cockpit delete pod -l app=cockpit"
    ok "Fleet Command deployed."
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
    title "Fleet Command — local demo with fake data (Ctrl-C to stop)"
    HOMELAB_DEMO=1 PORT="${PORT}" python3 "${REPO_ROOT}/cockpit/app.py"
    ;;
  *) die "Usage: cockpit.sh [install|open|demo]" ;;
esac
