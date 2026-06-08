#!/usr/bin/env bash
# List registered apps and optionally validate them or show cluster status.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

LIB="${SYSTEM_ROOT}/scripts/lib/app_config.py"
MODE="${1:-list}"

require_cmd python3

apps=()
if compgen -G "${SYSTEM_ROOT}/apps/*.yaml" >/dev/null; then
    while IFS= read -r f; do
        apps+=("$(basename "${f}" .yaml)")
    done < <(find "${SYSTEM_ROOT}/apps" -maxdepth 1 -name '*.yaml' -print | sort)
fi

if [[ "${#apps[@]}" -eq 0 ]]; then
    warn "No apps registered — run: make app-init NAME=myapp REPO=~/git/myapp"
    exit 0
fi

validate_app() {
    local app="$1"
    if python3 "${LIB}" "${app}" validate >/dev/null 2>&1; then
        echo OK
    else
        echo FAIL
    fi
}

cluster_status() {
    local app="$1" ns dep ready
    ns="$(python3 "${LIB}" "${app}" get namespace 2>/dev/null || echo "?")"
    dep="$(python3 "${LIB}" "${app}" get deployment 2>/dev/null || echo "?")"
    if ! kc get ns "${ns}" >/dev/null 2>&1; then
        echo "not deployed"
        return
    fi
    ready="$(kc -n "${ns}" get deploy "${dep}" \
        -o jsonpath='{.status.readyReplicas}/{.spec.replicas}' 2>/dev/null || echo "?/?")"
    echo "${ready} in ${ns}"
}

print_header() {
    printf "%-16s %-10s %-14s %s\n" "APP" "CONTRACT" "CLUSTER" "REPO"
    printf "%-16s %-10s %-14s %s\n" "---" "--------" "-------" "----"
}

case "${MODE}" in
    list|--list)
        print_header
        for app in "${apps[@]}"; do
            repo="$(python3 -c "import yaml; print(yaml.safe_load(open('${SYSTEM_ROOT}/apps/${app}.yaml'))['repo'])" 2>/dev/null || echo "?")"
            printf "%-16s %-10s %-14s %s\n" "${app}" "-" "$(cluster_status "${app}")" "${repo}"
        done
        ;;
    --validate-all|validate-all)
        failed=0
        print_header
        for app in "${apps[@]}"; do
            status="$(validate_app "${app}")"
            [[ "${status}" == OK ]] || failed=1
            repo="$(python3 -c "import yaml; print(yaml.safe_load(open('${SYSTEM_ROOT}/apps/${app}.yaml'))['repo'])" 2>/dev/null || echo "?")"
            printf "%-16s %-10s %-14s %s\n" "${app}" "${status}" "$(cluster_status "${app}")" "${repo}"
        done
        exit "${failed}"
        ;;
    -h|--help|help)
        cat <<EOF
Usage: list-apps.sh [list|validate-all]

  list           Show registered apps (default)
  validate-all   Validate every app contract; exit 1 if any fail
EOF
        ;;
    *)
        die "Unknown mode: ${MODE}"
        ;;
esac
