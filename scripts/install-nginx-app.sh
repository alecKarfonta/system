#!/usr/bin/env bash
# Install nginx edge routing for managed apps across all versioned sites.
#
# Source of truth (in this repo):
#   nginx/<site>.conf              — one site server block per domain (mlapi.us.conf, …)
#   nginx/snippets/*.conf          — shared location snippets (proxy, ssl, security, …)
#   nginx/apps/<site>/<app>.conf   — per-app location blocks, grouped by site
#   nginx/upstreams/<app>.conf     — per-app upstream server definitions
#
# Installed to (on the host):
#   /etc/nginx/sites-available/<site>     (symlinked from sites-enabled/)
#   /etc/nginx/snippets/*.conf
#   /etc/nginx/conf.d/apps/<site>/<app>.conf
#   /etc/nginx/conf.d/00-upstreams.conf   (one merged block per app upstream)
#
# Each site uses `include /etc/nginx/conf.d/apps/<site>/*.conf;` so newly
# installed app confs are picked up automatically — no per-app hand-editing
# of the site file, and apps from different sites cannot collide on
# root-level location blocks.
#
# Usage:
#   sudo install-nginx-app.sh <app> [site]   # install one app (site auto-detected or given)
#   sudo install-nginx-app.sh --all          # sync every site + snippet + every committed app
#   sudo install-nginx-app.sh --sites-only   # sync sites + snippets only
#   sudo install-nginx-app.sh --migrate      # move flat apps/*.conf into apps/<site>/ subdirs
#
# Requires sudo (writes under /etc/nginx and reloads nginx).

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

NGINX_SRC="${SYSTEM_ROOT}/nginx"
SNIPPETS_SRC="${NGINX_SRC}/snippets"
APPS_SRC="${NGINX_SRC}/apps"
UPSTREAMS_SRC="${NGINX_SRC}/upstreams"

SITES_AVAILABLE="/etc/nginx/sites-available"
SITES_ENABLED="/etc/nginx/sites-enabled"
SNIPPETS_DST="/etc/nginx/snippets"
APPS_DST_ROOT="/etc/nginx/conf.d/apps"
UPSTREAMS_FILE="/etc/nginx/conf.d/00-upstreams.conf"

usage() {
    cat <<EOF
Usage: sudo $0 <app [site]|--all|--sites-only|--migrate>

  <app> [site]   Install one app's conf + sync sites/snippets + merge upstream.
                 Site is auto-detected from nginx/apps/<site>/<app>.conf if
                 omitted; required if the app exists under multiple sites.
  --all          Sync every site + snippets + every committed app conf.
  --sites-only   Sync sites + snippets only (no app confs, no upstream changes).
  --migrate      Move existing flat /etc/nginx/conf.d/apps/*.conf files into
                 per-site subdirs. Prompts for each unknown app's site.

Sources from: ${NGINX_SRC}/
Installs to:  /etc/nginx/{sites-available,snippets,conf.d}/
EOF
}

require_root() {
    if [[ "$(id -u)" -ne 0 ]]; then
        die "Run with sudo: sudo $0 ${*:-<app|--all|--sites-only|--migrate>}"
    fi
}

backup() {
    local target="$1"
    [[ -e "${target}" ]] || return 0
    cp "${target}" "${target}.bak.$(date +%Y%m%d%H%M%S)"
}

# Enumerate every versioned site (e.g. mlapi.us, stockastic.us) from nginx/*.us.conf.
all_sites() {
    local f name
    shopt -s nullglob
    for f in "${NGINX_SRC}"/*.conf; do
        name="$(basename "${f}" .conf)"
        # Only treat files that look like site server blocks. Snippets live
        # under snippets/, so anything at the top level is a site.
        echo "${name}"
    done
    shopt -u nullglob
}

# Install one site file: symlink repo -> sites-available, ensure sites-enabled.
install_site() {
    local site="$1"
    local src="${NGINX_SRC}/${site}.conf"
    local dst="${SITES_AVAILABLE}/${site}"
    local enabled="${SITES_ENABLED}/${site}"

    [[ -f "${src}" ]] || die "Site source missing: ${src}"
    mkdir -p "${SITES_AVAILABLE}" "${SITES_ENABLED}"

    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
        # Real file (legacy hand-managed) — back it up and replace with symlink.
        backup "${dst}"
        warn "Replaced ${dst} (was a regular file) → symlink to repo"
        rm -f "${dst}"
    elif [[ -L "${dst}" && "$(readlink -f "${dst}")" != "${src}" ]]; then
        # Symlinked elsewhere — repoint to repo.
        rm -f "${dst}"
    fi

    ln -sf "${src}" "${dst}"
    ok "Site: ${dst} → ${src}"
    ln -sf "${dst}" "${enabled}"
    ok "Enabled: ${enabled}"
}

install_all_sites() {
    local site
    for site in $(all_sites); do
        install_site "${site}"
    done
}

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

# Ensure per-site subdir exists in /etc/nginx/conf.d/apps/.
ensure_site_app_dir() {
    local site="$1"
    mkdir -p "${APPS_DST_ROOT}/${site}"
}

# Auto-detect which site an app belongs to based on the repo layout.
# Errors if the app exists under more than one site (caller must disambiguate).
detect_site_for_app() {
    local app="$1"
    local site hits
    hits=()
    shopt -s nullglob
    for site in $(all_sites); do
        [[ -f "${APPS_SRC}/${site}/${app}.conf" ]] && hits+=("${site}")
    done
    shopt -u nullglob
    case "${#hits[@]}" in
        0) return 1 ;;
        1) echo "${hits[0]}" ;;
        *) die "App '${app}' exists under multiple sites: ${hits[*]}. Specify site: $0 ${app} <site>" ;;
    esac
}

# Install one app's location conf into /etc/nginx/conf.d/apps/<site>/.
install_app_conf() {
    local app="$1" site="$2"
    local src="${APPS_SRC}/${site}/${app}.conf"
    local dst_dir="${APPS_DST_ROOT}/${site}"
    local dst="${dst_dir}/${app}.conf"

    [[ -f "${src}" ]] || die "No nginx config at ${src}"
    ensure_site_app_dir "${site}"

    if [[ -f "${dst}" ]] && ! diff -q "${dst}" "${src}" >/dev/null 2>&1; then
        backup "${dst}"
    fi
    cp "${src}" "${dst}"
    ok "App conf: ${dst}"
}

# Merge every upstream block from a snippet file into 00-upstreams.conf.
merge_upstreams_from() {
    local snippet_path="$1"
    [[ -f "${snippet_path}" ]] || return 0
    [[ -f "${UPSTREAMS_FILE}" ]] || die "Missing ${UPSTREAMS_FILE}"
    backup "${UPSTREAMS_FILE}"

    python3 - "${UPSTREAMS_FILE}" "${snippet_path}" <<'PY'
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
print(f"merged {snippet_path.name}")
PY
}

install_app_upstream() {
    local app="$1"
    local upstream_src="${UPSTREAMS_SRC}/${app}.conf"
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

# Move flat /etc/nginx/conf.d/apps/*.conf files into per-site subdirs.
# Site detection order:
#   1. If a same-named conf exists in the repo (nginx/apps/<site>/), use that site.
#   2. Else if a site's old explicit include list is available as a backup
#      file in sites-available/ (made when the site was first migrated to
#      the glob form), parse it and assign accordingly.
#   3. Else fall back to a default site (MLAPI if mlapi.us exists, else first site).
migrate_flat_confs() {
    title "Migrating flat app confs to per-site subdirs"

    # Build {app -> site} map.
    declare -A assignment
    local bak site app

    # Rule 1: convention — "*-at-root" confs belong to stockastic.us
    # (root-level paths for the dedicated stocker domain).
    shopt -s nullglob
    for flat in "${APPS_DST_ROOT}"/*.conf; do
        app="$(basename "${flat}" .conf)"
        if [[ "${app}" == *-at-root ]] && [[ -f "${NGINX_SRC}/stockastic.us.conf" ]]; then
            assignment[${app}]="stockastic.us"
        fi
    done

    # Rule 2: parse old explicit-include backups of each known site.
    for bak in "${SITES_AVAILABLE}"/*.bak.*; do
        site="$(basename "${bak}" | sed -E 's/^([^.]+(\.[^.]+)*)\.bak\..*$/\1/')"
        [[ -f "${NGINX_SRC}/${site}.conf" ]] || continue
        while IFS= read -r line; do
            app="$(echo "${line}" | sed -E 's|.*/apps/([^/]+\.conf).*|\1|; s/\.conf$//')"
            [[ -n "${app}" && "${app}" != "*" ]] || continue
            [[ -n "${assignment[${app}]:-}" ]] || assignment[${app}]="${site}"
        done < <(grep "include.*apps/" "${bak}" 2>/dev/null || true)
    done
    shopt -u nullglob

    # Fallback site.
    local default_site
    for site in $(all_sites); do
        if [[ "${site}" == "mlapi.us" ]]; then default_site="${site}"; break; fi
    done
    default_site="${default_site:-$(all_sites | head -1)}"
    [[ -n "${default_site}" ]] || die "No sites available — nothing to migrate to"

    shopt -s nullglob
    local flat repo_site dst
    for flat in "${APPS_DST_ROOT}"/*.conf; do
        app="$(basename "${flat}" .conf)"
        if [[ -n "${assignment[${app}]:-}" ]]; then
            site="${assignment[${app}]}"
        elif repo_site="$(detect_site_for_app "${app}" 2>/dev/null)"; then
            site="${repo_site}"
        else
            site="${default_site}"
            warn "${app}: not in repo or any backup include list — defaulting to ${site}/"
        fi
        ensure_site_app_dir "${site}"
        dst="${APPS_DST_ROOT}/${site}/${app}.conf"
        if [[ -f "${dst}" ]]; then
            warn "${app}: target ${site}/${app}.conf already exists — leaving flat copy"
            warn "  Inspect and remove manually: sudo rm ${flat}"
        else
            mv "${flat}" "${dst}"
            ok "${app}: → ${site}/"
        fi
    done
    shopt -u nullglob

    # Warn about any leftover flat files (the above loop may have skipped some).
    local leftover=()
    shopt -s nullglob
    for flat in "${APPS_DST_ROOT}"/*.conf; do leftover+=("$(basename "${flat}")"); done
    shopt -u nullglob
    if [[ "${#leftover[@]}" -gt 0 ]]; then
        warn "Leftover flat confs (need manual triage): ${leftover[*]}"
    fi
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
    install_all_sites
    install_snippets

    case "${mode}" in
        --sites-only)
            reload_nginx
            ok "Sites + snippets synced (no app confs touched)"
            ;;
        --all)
            local site src app
            shopt -s nullglob
            for site in $(all_sites); do
                ensure_site_app_dir "${site}"
                for src in "${APPS_SRC}/${site}"/*.conf; do
                    app="$(basename "${src}" .conf)"
                    install_app_conf "${app}" "${site}"
                    install_app_upstream "${app}"
                done
            done
            shopt -u nullglob
            reload_nginx
            ok "All sites + apps synced"
            ;;
        --migrate)
            migrate_flat_confs
            warn "Run 'sudo $0 --sites-only' (or --all) next to reload nginx"
            ;;
        *)
            # Single app name, optionally followed by site.
            local app="${mode}" site="${2:-}"
            if [[ -z "${site}" ]]; then
                site="$(detect_site_for_app "${app}")" \
                    || die "App '${app}' not found under any site. Spec site explicitly: $0 ${app} <site>"
            fi
            if [[ ! -f "${APPS_SRC}/${site}/${app}.conf" ]]; then
                die "No app conf: ${APPS_SRC}/${site}/${app}.conf"
            fi
            install_app_conf "${app}" "${site}"
            install_app_upstream "${app}"
            reload_nginx
            ok "App '${app}' installed (site: ${site})"
            ;;
    esac
}

main "$@"
