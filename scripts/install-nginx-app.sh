#!/usr/bin/env bash
# Install nginx edge routing for managed apps on the mlapi.us host.
#
# Source of truth (in this repo):
#   nginx/mlapi.us.conf       — site server block (TLS, server_name, app include glob)
#   nginx/snippets/*.conf     — shared location snippets (proxy, ssl, security, …)
#   nginx/apps/<app>.conf     — per-app location blocks
#   nginx/upstreams/<app>.conf — per-app upstream server definitions
#
# Installed to (on the host):
#   /etc/nginx/sites-available/mlapi.us   (symlinked from sites-enabled/)
#   /etc/nginx/snippets/*.conf
#   /etc/nginx/conf.d/apps/<app>.conf
#   /etc/nginx/conf.d/00-upstreams.conf   (one merged block per app upstream)
#
# The mlapi.us site uses `include /etc/nginx/conf.d/apps/*.conf;` so newly
# installed app confs are picked up automatically — no per-app hand-editing
# of the site file.
#
# Usage:
#   sudo install-nginx-app.sh <app>        # install one app + sync site/snippets
#   sudo install-nginx-app.sh --all        # sync site/snippets + every app in nginx/apps/
#   sudo install-nginx-app.sh --site-only  # sync site + snippets only (no app confs)
#
# Requires sudo (writes under /etc/nginx and reloads nginx).

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

SITE_SRC="${SYSTEM_ROOT}/nginx/mlapi.us.conf"
SITE_DST="/etc/nginx/sites-available/mlapi.us"
SITE_ENABLED="/etc/nginx/sites-enabled/mlapi.us"
SNIPPETS_SRC="${SYSTEM_ROOT}/nginx/snippets"
SNIPPETS_DST="/etc/nginx/snippets"
APPS_DST_DIR="/etc/nginx/conf.d/apps"
UPSTREAMS_FILE="/etc/nginx/conf.d/00-upstreams.conf"

usage() {
    cat <<EOF
Usage: sudo $0 <app|--all|--site-only>

  <app>        Install one app's conf + sync site/snippets + merge upstream.
  --all        Sync site/snippets and install every nginx/apps/*.conf.
  --site-only  Sync site + snippets only (no app confs, no upstream changes).

Sources from: ${SYSTEM_ROOT}/nginx/
Installs to:  /etc/nginx/{sites-available,snippets,conf.d}/
EOF
}

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "Run with sudo: sudo $0 ${*:-<app|--all|--site-only>}"
    fi
}

backup() {
    local target="$1"
    [[ -e "${target}" ]] || return 0
    cp "${target}" "${target}.bak.$(date +%Y%m%d%H%M%S)"
}

# Install the mlapi.us site block + symlink it into sites-enabled.
install_site() {
    [[ -f "${SITE_SRC}" ]] || die "Site source missing: ${SITE_SRC}"
    mkdir -p /etc/nginx/sites-available /etc/nginx/sites-enabled

    if [[ -f "${SITE_DST}" && ! -L "${SITE_DST}" ]]; then
        # Real file (legacy hand-managed) — back it up before replacing.
        if ! diff -q "${SITE_DST}" "${SITE_SRC}" >/dev/null 2>&1; then
            backup "${SITE_DST}"
            warn "Existing ${SITE_DST} differs from repo — backed up and replaced"
        fi
        rm -f "${SITE_DST}"
    fi

    # Always symlink so future `systemctl reload` picks up repo edits directly.
    ln -sf "${SITE_SRC}" "${SITE_DST}"
    ok "Site: ${SITE_DST} → ${SITE_SRC}"

    ln -sf "${SITE_DST}" "${SITE_ENABLED}"
    ok "Enabled: ${SITE_ENABLED}"
}

# Sync every snippet from the repo into /etc/nginx/snippets/.
install_snippets() {
    [[ -d "${SNIPPETS_SRC}" ]] || { warn "No snippets dir at ${SNIPPETS_SRC}"; return 0; }
    mkdir -p "${SNIPPETS_DST}"
    local src dst name
    shopt -s nullglob
    for src in "${SNIPPETS_SRC}"/*.conf; do
        name="$(basename "${src}")"
        dst="${SNIPPETS_DST}/${name}"
        if [[ -f "${dst}" && ! -L "${dst}" ]] && ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
            backup "${dst}"
        fi
        cp "${src}" "${dst}"
    done
    shopt -u nullglob
    ok "Snippets synced → ${SNIPPETS_DST}/"
}

# Install one app's location conf into /etc/nginx/conf.d/apps/.
install_app_conf() {
    local app="$1"
    local src="${SYSTEM_ROOT}/nginx/apps/${app}.conf"
    local dst="${APPS_DST_DIR}/${app}.conf"

    [[ -f "${src}" ]] || die "No nginx config at ${src}"
    mkdir -p "${APPS_DST_DIR}"

    if [[ -f "${dst}" ]] && ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
        backup "${dst}"
    fi
    cp "${src}" "${dst}"
    ok "App conf: ${dst}"
}

# Merge every upstream block from a snippet file into 00-upstreams.conf.
# `snippet_path` may contain multiple `upstream NAME { … }` blocks separated by
# blank lines; existing blocks with the same name are replaced, new ones appended.
merge_upstreams_from() {
    local snippet_path="$1"
    [[ -f "${snippet_path}" ]] || return 0
    [[ -f "${UPSTREAMS_FILE}" ]] || die "Missing ${UPSTREAMS_FILE}"

    # Only back up if we're actually about to change it.
    cp "${UPSTREAMS_FILE}" "${UPSTREAMS_FILE}.tmp.before"

    python3 - "${UPSTREAMS_FILE}" "${snippet_path}" <<'PY'
import pathlib
import re
import sys

upstreams_path = pathlib.Path(sys.argv[1])
snippet_path = pathlib.Path(sys.argv[2])
text = upstreams_path.read_text()
original = text
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

if text != original:
    upstreams_path.write_text(text)
    print(f"merged {snippet_path.name}")
else:
    print(f"unchanged {snippet_path.name}")
PY

    if ! diff -q "${UPSTREAMS_FILE}" "${UPSTREAMS_FILE}.tmp.before" >/dev/null 2>&1; then
        backup "${UPSTREAMS_FILE}.tmp.before"  # keep one snapshot of pre-change state
        mv "${UPSTREAMS_FILE}.tmp.before" "${UPSTREAMS_FILE}.bak.last-change" 2>/dev/null || true
    fi
    rm -f "${UPSTREAMS_FILE}.tmp.before"
}

# Sync the upstream for a single app (if its upstream conf exists in the repo).
install_app_upstream() {
    local app="$1"
    local upstream_src="${SYSTEM_ROOT}/nginx/upstreams/${app}.conf"
    if [[ -f "${upstream_src}" ]]; then
        merge_upstreams_from "${upstream_src}"
        ok "Upstream merged for ${app}"
    fi
}

reload_nginx() {
    title "Reloading nginx"
    if ! nginx -t; then
        die "nginx -t failed — config not reloaded. Inspect /etc/nginx/ and fix."
    fi
    systemctl reload nginx
    ok "nginx reloaded"
}

main() {
    local mode="${1:-}"

    case "${mode}" in
        --help|-h|"") usage; exit 0 ;;
    esac

    require_root "${mode}"
    require_cmd nginx
    require_cmd systemctl

    title "Syncing nginx edge config"
    install_site
    install_snippets

    case "${mode}" in
        --site-only)
            reload_nginx
            ok "Site + snippets synced (no app confs touched)"
            ;;
        --all)
            local src
            shopt -s nullglob
            for src in "${SYSTEM_ROOT}"/nginx/apps/*.conf; do
                local app
                app="$(basename "${src}" .conf)"
                install_app_conf "${app}"
                install_app_upstream "${app}"
            done
            shopt -u nullglob
            reload_nginx
            ok "All apps synced"
            ;;
        *)
            # Single app name.
            if [[ ! -f "${SYSTEM_ROOT}/nginx/apps/${mode}.conf" ]]; then
                die "No app conf: ${SYSTEM_ROOT}/nginx/apps/${mode}.conf"
            fi
            install_app_conf "${mode}"
            install_app_upstream "${mode}"
            reload_nginx
            ok "App '${mode}' installed"
            ;;
    esac
}

main "$@"
