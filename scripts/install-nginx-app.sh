#!/bin/bash
# Install one app's nginx config from the system repo onto the mlapi.us host.
# Requires sudo.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:?Usage: install-nginx-app.sh <app-name>}"

APP_CONF="${SYSTEM_ROOT}/nginx/apps/${APP}.conf"
TARGET_CONF="/etc/nginx/conf.d/apps/${APP}.conf"
UPSTREAMS_FILE="/etc/nginx/conf.d/00-upstreams.conf"
UPSTREAM_SNIPPET="${SYSTEM_ROOT}/nginx/00-upstreams.snippet.conf"

if [ "$(id -u)" -ne 0 ]; then
    echo "Run with sudo: sudo $0 ${APP}" >&2
    exit 1
fi

if [ ! -f "${APP_CONF}" ]; then
    echo "No nginx config at ${APP_CONF}" >&2
    exit 1
fi

cp "${TARGET_CONF}" "${TARGET_CONF}.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
cp "${APP_CONF}" "${TARGET_CONF}"
echo "Installed ${TARGET_CONF}"

if [ -f "${UPSTREAM_SNIPPET}" ] && [ -f "${UPSTREAMS_FILE}" ]; then
    cp "${UPSTREAMS_FILE}" "${UPSTREAMS_FILE}.bak.$(date +%Y%m%d%H%M%S)"
    python3 - "${UPSTREAMS_FILE}" "${UPSTREAM_SNIPPET}" <<'PY'
import pathlib
import re
import sys

upstreams_path = pathlib.Path(sys.argv[1])
snippet_path = pathlib.Path(sys.argv[2])
text = upstreams_path.read_text()
snippet = snippet_path.read_text().strip()

for block in snippet.split("\n\n"):
    if not block.strip():
        continue
    name_match = re.search(r"upstream\s+(\S+)", block)
    if not name_match:
        continue
    name = name_match.group(1)
    pattern = rf"upstream {re.escape(name)} \{{[^}}]*\}}\n?"
    if re.search(pattern, text):
        text = re.sub(pattern, block + "\n\n", text)
    else:
        text = text.rstrip() + "\n\n" + block + "\n"

upstreams_path.write_text(text)
print(f"Merged upstreams from {snippet_path.name}")
PY
fi

nginx -t
systemctl reload nginx
echo "Nginx reloaded for app: ${APP}"
