#!/usr/bin/env bash
# Resolve LoadBalancer address and patch nginx upstream snippets for an app.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

APP="${1:?Usage: sync-nginx-upstream.sh <app>}"
LIB="${SYSTEM_ROOT}/scripts/lib/app_config.py"

require_cmd python3

CONFIG_JSON="$(python3 "${LIB}" "${APP}" export)"
eval "$(python3 - "${CONFIG_JSON}" <<'PY'
import json, shlex, sys
c = json.loads(sys.argv[1])
fields = {
    "NGINX_APP": c.get("nginx_app") or "",
    "NGINX_HOST": c.get("nginx_host") or "auto",
    "NGINX_NAMESPACE": c.get("namespace") or "",
    "NGINX_SERVICE": c.get("nginx_service") or c.get("deployment") or "",
    "NGINX_SERVICE_PORT": c.get("nginx_service_port") or "http",
}
for k, v in fields.items():
    print(f"{k}={shlex.quote(str(v))}")
PY
)"

[[ -n "${NGINX_APP}" ]] || die "App '${APP}' has no nginx.name in system.yaml"

UPSTREAM_FILE="${SYSTEM_ROOT}/nginx/upstreams/${NGINX_APP}.conf"
[[ -f "${UPSTREAM_FILE}" ]] || die "Missing ${UPSTREAM_FILE}"

load_env 2>/dev/null || true

resolve_host() {
    if [[ -n "${MLAPI_UPSTREAM_HOST:-}" ]]; then
        echo "${MLAPI_UPSTREAM_HOST}"
        return
    fi
    if [[ "${NGINX_HOST}" != "auto" && -n "${NGINX_HOST}" ]]; then
        echo "${NGINX_HOST}"
        return
    fi
    if [[ "${MLAPI_USE_LB:-}" == "1" ]]; then
        local lb_ip
        lb_ip="$(kc -n "${NGINX_NAMESPACE}" get svc "${NGINX_SERVICE}" \
            -o jsonpath="{.status.loadBalancer.ingress[0].ip}" 2>/dev/null || true)"
        if [[ -n "${lb_ip}" ]]; then
            echo "${lb_ip}"
            return
        fi
    fi
    echo "127.0.0.1"
}

RESOLVED_HOST="$(resolve_host)"
info "nginx upstream host for ${APP}: ${RESOLVED_HOST}"

python3 - "${UPSTREAM_FILE}" "${CONFIG_JSON}" "${RESOLVED_HOST}" <<'PY'
import json
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
config = json.loads(sys.argv[2])
host = sys.argv[3]
nginx = config.get("nginx") or {}
upstreams = nginx.get("upstreams") or {}

if not upstreams:
    port = nginx.get("port") or 8080
    name = nginx.get("upstream") or f"host196_{config['app']}_api"
    upstreams = {name: port}

text = path.read_text()
for name, port in upstreams.items():
    pattern = rf"(upstream {re.escape(name)} \{{\n\s*server )[^;]+;"
    repl = rf"\g<1>{host}:{port};"
    if re.search(pattern, text):
        text = re.sub(pattern, repl, text)
    else:
        text = text.rstrip() + f"\n\nupstream {name} {{\n    server {host}:{port};\n    keepalive 8;\n}}\n"

path.write_text(text)
for name, port in upstreams.items():
    print(f"  {name} → {host}:{port}")
PY

ok "Updated ${UPSTREAM_FILE}"
