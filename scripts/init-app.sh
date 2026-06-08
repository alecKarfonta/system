#!/usr/bin/env bash
# Scaffold a new app repo from schema/app-scaffold and register it with system.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

NAME="${NAME:-${1:-}}"
REPO="${REPO:-${2:-}}"
PORT="${PORT:-8080}"
CPU_TIER="${CPU_TIER:-cheap}"
GHCR_ORG="${GHCR_ORG:-aleckarfonta}"
REGISTER="${REGISTER:-1}"
SCAFFOLD="${SYSTEM_ROOT}/schema/app-scaffold"

usage() {
    cat <<EOF
Usage: init-app.sh NAME REPO [options via env]

Creates app repo layout from schema/app-scaffold and registers apps/<name>.yaml.

Environment:
  NAME          App name (required, lowercase alphanumeric + hyphen)
  REPO          Target repo path (required)
  PORT          Container / service port (default: 8080)
  CPU_TIER      homelab/cpu-tier for homelab overlay (default: cheap)
  GHCR_ORG      GitHub org for production image path (default: aleckarfonta)
  REGISTER=0    Skip creating apps/<name>.yaml

Example:
  make app-init NAME=widget REPO=~/git/widget
EOF
}

[[ -n "${NAME}" && -n "${REPO}" ]] || { usage; exit 1; }

if [[ ! "${NAME}" =~ ^[a-z][a-z0-9-]*$ ]]; then
    die "Invalid NAME '${NAME}' — use lowercase letters, digits, hyphens"
fi

if [[ ! -d "${SCAFFOLD}" ]]; then
    die "Scaffold missing: ${SCAFFOLD}"
fi

REPO="$(eval echo "${REPO}")"
mkdir -p "${REPO}"
REPO="$(cd "${REPO}" && pwd)"

if [[ -f "${REPO}/system.yaml" ]]; then
    die "Refusing to overwrite existing ${REPO}/system.yaml"
fi

subst() {
    sed -e "s/__APP_NAME__/${NAME}/g" \
        -e "s/__APP_PORT__/${PORT}/g" \
        -e "s/__CPU_TIER__/${CPU_TIER}/g" \
        -e "s/__GHCR_ORG__/${GHCR_ORG}/g"
}

copy_tree() {
    local src="$1" dst="$2"
    local rel path
    while IFS= read -r -d '' file; do
        rel="${file#"${src}/"}"
        [[ "${rel}" == nginx/* ]] && continue
        path="${dst}/${rel}"
        mkdir -p "$(dirname "${path}")"
        subst < "${file}" > "${path}"
    done < <(find "${src}" -type f -print0)
}

title "Scaffolding app '${NAME}' → ${REPO}"
copy_tree "${SCAFFOLD}" "${REPO}"
chmod +x "${REPO}/scripts/deploy-k8s.sh"

NGINX_APP="${SYSTEM_ROOT}/nginx/apps/${NAME}.conf"
NGINX_UP="${SYSTEM_ROOT}/nginx/upstreams/${NAME}.conf"
if [[ ! -f "${NGINX_APP}" ]]; then
    mkdir -p "$(dirname "${NGINX_APP}")" "$(dirname "${NGINX_UP}")"
    subst < "${SCAFFOLD}/nginx/apps/app.conf" > "${NGINX_APP}"
    subst < "${SCAFFOLD}/nginx/upstreams/app.conf" > "${NGINX_UP}"
    ok "Created nginx configs: nginx/apps/${NAME}.conf"
else
    warn "nginx/apps/${NAME}.conf exists — not overwriting"
fi

REGISTRY="${SYSTEM_ROOT}/apps/${NAME}.yaml"
if [[ "${REGISTER}" == "1" ]]; then
    if [[ -f "${REGISTRY}" ]]; then
        warn "Already registered: ${REGISTRY}"
    else
        printf 'repo: %s\n' "${REPO}" > "${REGISTRY}"
        ok "Registered apps/${NAME}.yaml"
    fi
fi

python3 "${SYSTEM_ROOT}/scripts/lib/app_config.py" "${NAME}" validate
ok "Scaffold ready — edit ${REPO}/system.yaml and implement your app"
info "Next: make app-deploy APP=${NAME}"
