#!/usr/bin/env bash
# Deploy a registered app to the managed k3s cluster.
# Requires: apps/<name>.yaml and system.yaml in the app repo.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SYSTEM_ROOT}/scripts/lib/common.sh"

APP="${1:?Usage: deploy-app.sh <app> [deploy|validate|diff|delete|status|verify]}"
COMMAND="${2:-deploy}"
LIB="${SYSTEM_ROOT}/scripts/lib/app_config.py"

require_cmd python3
require_cmd docker

load_config() {
    CONFIG_JSON="$(python3 "${LIB}" "${APP}" export)"
    eval "$(python3 - "${CONFIG_JSON}" <<'PY'
import json
import shlex
import sys

config = json.loads(sys.argv[1])
fields = {
    "CONFIG_NAMESPACE": config["namespace"],
    "CONFIG_DEPLOYMENT": config["deployment"],
    "CONFIG_REPO": config["repo"],
    "CONFIG_OVERLAY": config["overlay"],
    "CONFIG_K8S_PATH": config["k8s_path"],
    "CONFIG_COMPOSE_FILE": config["compose_file"],
    "CONFIG_COMPOSE_SERVICE": config["compose_service"],
    "CONFIG_IMAGE_LOCAL": config.get("image_local") or "",
    "CONFIG_IMAGE_REGISTRY": config.get("image_registry") or "",
    "CONFIG_IMAGE_TAG": config["image_tag"],
    "CONFIG_REGISTRY_PUSH": config["registry_push"],
    "CONFIG_IMPORT_NODES": config.get("import_nodes") or "",
    "CONFIG_HOMELAB_DELIVERY": config.get("homelab_delivery") or "import",
    "CONFIG_HOMELAB_REGISTRY_REPO": config.get("homelab_registry_repo") or "",
    "CONFIG_HOMELAB_REGISTRY_TAG": config.get("homelab_registry_tag") or "local",
    "CONFIG_STORAGE_SESSIONS": config.get("storage_sessions") or "emptydir",
    "CONFIG_NGINX_APP": config.get("nginx_app") or "",
}
for key, value in fields.items():
    print(f"{key}={shlex.quote(str(value))}")
PY
)"
}

usage() {
    local apps=""
    if compgen -G "${SYSTEM_ROOT}/apps/*.yaml" >/dev/null; then
        apps="$(basename -a "${SYSTEM_ROOT}"/apps/*.yaml 2>/dev/null | sed 's/.yaml//')"
    fi
    cat <<EOF
Usage: $0 <app> [command]

Commands:
  deploy     Build (if needed), apply manifests, wait for rollout, verify
  validate   Check registry + repo system.yaml + k8s layout
  diff       Show manifest diff against cluster
  delete     Remove app resources from cluster
  status     Show namespace resources
  verify     Run health checks from repo system.yaml

Registered apps: ${apps:-none}

Environment:
  K8S_OVERLAY         homelab (default) or production
  HOMELAB_DELIVERY    import (default) or registry — overrides system.yaml
  SESSIONS_STORAGE    emptyDir or pvc — overrides system.yaml storage.sessions.type
  KUBECONFIG          kubeconfig path
  IMAGE_TAG           registry tag for production overlay
  KUBECTL_CONTEXT     optional kubectl context
  SKIP_VERIFY=1       skip post-deploy health checks
  SKIP_NGINX=1        skip nginx upstream sync + install
  INSTALL_NGINX=1     run sudo install-nginx-app.sh when possible (default: 1)
EOF
}

kustomize_build() {
    kc kustomize "${CONFIG_K8S_PATH}" --load-restrictor LoadRestrictionsNone
}

apply_manifests() {
    kustomize_build | kc apply --server-side --field-manager=system-deploy --force-conflicts -f -
}

# Apply just the namespace so the import step (which schedules a Pod in the
# namespace) can run before the full manifest apply. Idempotent — uses
# server-side apply so it won't conflict with the later full apply.
ensure_namespace() {
    local ns_file="${CONFIG_REPO}/k8s/base/namespace.yaml"
    if [[ -f "${ns_file}" ]]; then
        kc apply --server-side --field-manager=system-deploy -f "${ns_file}" >/dev/null 2>&1 || true
    else
        kc create namespace "${CONFIG_NAMESPACE}" --dry-run=client -o yaml \
            | kc apply --server-side --field-manager=system-deploy -f - >/dev/null 2>&1 || true
    fi
}

tag_built_image() {
    if docker image inspect "${CONFIG_IMAGE_LOCAL}" >/dev/null 2>&1; then
        ok "Image ready: ${CONFIG_IMAGE_LOCAL}"
        return
    fi

    local built_id compose_image
    built_id="$(cd "${CONFIG_REPO}" && docker compose -f "${CONFIG_COMPOSE_FILE}" \
        images -q "${CONFIG_COMPOSE_SERVICE}" 2>/dev/null | head -1)"
    if [[ -n "${built_id}" ]]; then
        docker tag "${built_id}" "${CONFIG_IMAGE_LOCAL}"
        ok "Tagged ${CONFIG_IMAGE_LOCAL}"
        return
    fi

    compose_image="$(python3 - "${CONFIG_COMPOSE_FILE}" "${CONFIG_COMPOSE_SERVICE}" <<'PY'
import sys, yaml
data = yaml.safe_load(open(sys.argv[1]))
svc = (data.get("services") or {}).get(sys.argv[2]) or {}
print(svc.get("image") or "")
PY
)"
    if [[ -n "${compose_image}" ]] && docker image inspect "${compose_image}" >/dev/null 2>&1; then
        docker tag "${compose_image}" "${CONFIG_IMAGE_LOCAL}"
        ok "Tagged ${CONFIG_IMAGE_LOCAL} from ${compose_image}"
        return
    fi

    die "No image produced for compose service '${CONFIG_COMPOSE_SERVICE}'"
}

build_compose_image() {
    title "Building ${CONFIG_COMPOSE_SERVICE} in ${CONFIG_REPO}"
    (cd "${CONFIG_REPO}" && docker compose -f "${CONFIG_COMPOSE_FILE}" build "${CONFIG_COMPOSE_SERVICE}")
    tag_built_image
}

deliver_homelab_image() {
    case "${CONFIG_HOMELAB_DELIVERY}" in
        import)
            K3S_IMPORT_NAMESPACE="${CONFIG_NAMESPACE}" \
                K3S_IMPORT_NODES="${CONFIG_IMPORT_NODES}" \
                "${SYSTEM_ROOT}/scripts/import-k3s-image.sh" "${CONFIG_IMAGE_LOCAL}"
            ;;
        registry)
            load_env
            local pass addr repo tag remote f
            if [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
                pass="${REGISTRY_PASSWORD}"
            else
                f="${REPO_ROOT}/config/.registry-password"
                [[ -f "$f" ]] || die "Homelab registry password missing — run: make registry"
                pass="$(tr -d '\n' < "$f")"
            fi
            addr="${REGISTRY_HOST:-${SERVER_HOST}}:${REGISTRY_NODEPORT:-30500}"
            repo="${CONFIG_HOMELAB_REGISTRY_REPO}"
            tag="${CONFIG_HOMELAB_REGISTRY_TAG}"
            remote="${addr}/${repo}:${tag}"
            info "Pushing to homelab registry: ${remote}"
            echo "${pass}" | docker login "https://${addr}" -u "${REGISTRY_USER:-homelab}" --password-stdin
            docker tag "${CONFIG_IMAGE_LOCAL}" "${remote}"
            docker push "${remote}"
            ok "Pushed ${remote} (homelab overlay must reference this image)"
            ;;
        *)
            die "Unknown homelab delivery: ${CONFIG_HOMELAB_DELIVERY}"
            ;;
    esac
}

build_production_image() {
    build_compose_image
    local production_image="${CONFIG_IMAGE_REGISTRY}:${CONFIG_IMAGE_TAG}"
    docker tag "${CONFIG_IMAGE_LOCAL}" "${production_image}"
    if [[ "${CONFIG_REGISTRY_PUSH}" == "True" ]]; then
        info "Pushing ${production_image}..."
        docker push "${production_image}"
    else
        info "Skipping push (build.registry.push is false)"
    fi
}

run_verify() {
    python3 - "${CONFIG_JSON}" <<'PY'
import json
import sys
import urllib.error
import urllib.request

config = json.loads(sys.argv[1])
checks = config.get("verify") or []
if not checks:
    print("No verify checks defined in system.yaml")
    sys.exit(0)

failures = []
for check in checks:
    url = check["url"]
    expect = check.get("expect_status", 200)
    desc = check.get("description", url)
    # Cloudflare Bot Fight Mode 403s requests with no/empty User-Agent.
    # urllib's default UA is "Python-urllib/<ver>" which is enough on most
    # origins, but be explicit so verify works reliably behind any edge.
    request = urllib.request.Request(
        url, method="GET", headers={"User-Agent": "system-deploy-verify/1.0"}
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            status = response.status
    except urllib.error.HTTPError as exc:
        status = exc.code
    except Exception as exc:
        failures.append(f"{desc}: {exc}")
        continue
    if status != expect:
        failures.append(f"{desc}: expected HTTP {expect}, got {status}")
    else:
        print(f"OK: {desc} ({url})")

if failures:
    for failure in failures:
        print(f"FAIL: {failure}", file=sys.stderr)
    sys.exit(1)
PY
}

install_nginx_if_configured() {
    [[ -n "${CONFIG_NGINX_APP:-}" ]] || return 0
    [[ "${SKIP_NGINX:-}" == "1" ]] && return 0

    title "Nginx edge routing"
    "${SYSTEM_ROOT}/scripts/sync-nginx-upstream.sh" "${APP}"

    if [[ "${INSTALL_NGINX:-1}" != "1" ]]; then
        info "Skipping nginx install (INSTALL_NGINX=0)"
        return 0
    fi

    local installer="${SYSTEM_ROOT}/scripts/install-nginx-app.sh"
    # Per-site subdir layout (nginx/apps/<site>/<app>.conf) is canonical;
    # a flat nginx/apps/<app>.conf is accepted for backwards compat.
    local nginx_app_conf=""
    while IFS= read -r -d '' conf; do
        nginx_app_conf="${conf}"
        break
    done < <(find "${SYSTEM_ROOT}/nginx/apps" -type f -name "${CONFIG_NGINX_APP}.conf" -print0 2>/dev/null)
    if [[ -z "${nginx_app_conf}" ]]; then
        warn "No nginx/apps/<site>/${CONFIG_NGINX_APP}.conf — skipping install"
        return 0
    fi

    if [[ "$(id -u)" -eq 0 ]]; then
        "${installer}" "${CONFIG_NGINX_APP}"
    elif sudo -n true 2>/dev/null; then
        sudo "${installer}" "${CONFIG_NGINX_APP}"
    else
        warn "Run: sudo ${installer} ${CONFIG_NGINX_APP}"
    fi
}

deploy() {
    load_config
    python3 "${LIB}" "${APP}" validate

    if ! kc cluster-info >/dev/null 2>&1; then
        die "Cannot reach Kubernetes cluster"
    fi

    info "storage.sessions.type=${CONFIG_STORAGE_SESSIONS} (override: SESSIONS_STORAGE=emptyDir|pvc)"

    # Ensure the namespace exists before importing images — the import step
    # schedules a Pod in this namespace and fails if it doesn't exist yet.
    ensure_namespace

    if [[ "${CONFIG_OVERLAY}" == "homelab" ]]; then
        build_compose_image
        deliver_homelab_image
    elif [[ "${CONFIG_OVERLAY}" == "production" ]]; then
        build_production_image
    fi

    title "Applying overlay '${CONFIG_OVERLAY}' → namespace '${CONFIG_NAMESPACE}'"
    apply_manifests

    info "Waiting for rollout deployment/${CONFIG_DEPLOYMENT}..."
    kc -n "${CONFIG_NAMESPACE}" rollout status "deployment/${CONFIG_DEPLOYMENT}" --timeout=300s
    kc -n "${CONFIG_NAMESPACE}" get pods,svc -o wide

    # Install edge routing BEFORE verify so the public health check can reach
    # the freshly-deployed pods on a first deploy. Use SKIP_NGINX=1 to defer.
    install_nginx_if_configured

    if [[ "${SKIP_VERIFY:-}" != "1" ]]; then
        title "Verify checks"
        run_verify
    fi
}

case "${COMMAND}" in
    deploy) deploy ;;
    validate) python3 "${LIB}" "${APP}" validate ;;
    diff)
        load_config
        kustomize_build | kc diff -f - || true
        ;;
    delete)
        load_config
        kustomize_build | kc delete -f - --ignore-not-found
        ;;
    status)
        load_config
        kc -n "${CONFIG_NAMESPACE}" get all,configmap
        ;;
    verify)
        load_config
        run_verify
        ;;
    -h|--help|help) usage ;;
    *)
        die "Unknown command: ${COMMAND}"
        ;;
esac
