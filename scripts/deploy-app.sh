#!/bin/bash
# Deploy a registered app to the managed k3s cluster.
# Requires: app registered in apps/<name>.yaml and system.yaml in the repo.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:?Usage: deploy-app.sh <app> [deploy|validate|diff|delete|status|verify]}"
COMMAND="${2:-deploy}"
LIB="${SYSTEM_ROOT}/scripts/lib/app_config.py"

export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

if [ ! -f "${LIB}" ]; then
    echo "Missing config loader: ${LIB}" >&2
    exit 1
fi

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
}
for key, value in fields.items():
    print(f"{key}={shlex.quote(str(value))}")
PY
)"
}

usage() {
    cat <<EOF
Usage: $0 <app> [command]

Commands:
  deploy     Build (if needed), apply manifests, wait for rollout, verify
  validate   Check registry + repo system.yaml + k8s layout
  diff       Show manifest diff against cluster
  delete     Remove app resources from cluster
  status     Show namespace resources
  verify     Run health checks from repo system.yaml

Registered apps: $(basename -a "${SYSTEM_ROOT}"/apps/*.yaml 2>/dev/null | sed 's/.yaml//')

Environment:
  K8S_OVERLAY       homelab (default) or production
  KUBECONFIG        kubeconfig path
  IMAGE_TAG         registry tag for production overlay
  KUBECTL_CONTEXT   optional kubectl context
  SYSTEM_ROOT       path to system repo
  SKIP_VERIFY=1     skip post-deploy health checks
EOF
}

kubectl_cmd() {
    if [ -n "${KUBECTL_CONTEXT:-}" ]; then
        kubectl --context "${KUBECTL_CONTEXT}" "$@"
    else
        kubectl "$@"
    fi
}

kustomize_build() {
    kubectl_cmd kustomize "${CONFIG_K8S_PATH}" --load-restrictor LoadRestrictionsNone
}

apply_manifests() {
    kustomize_build | kubectl_cmd apply --server-side --field-manager=system-deploy --force-conflicts -f -
}

build_homelab_image() {
    echo "Building ${CONFIG_COMPOSE_SERVICE} in ${CONFIG_REPO}..."
    docker compose -f "${CONFIG_COMPOSE_FILE}" build "${CONFIG_COMPOSE_SERVICE}"
    compose_image="$(grep -E '^    image:' "${CONFIG_COMPOSE_FILE}" | head -1 | awk '{print $2}')"
    docker tag "${compose_image}" "${CONFIG_IMAGE_LOCAL}"
    K3S_IMPORT_NAMESPACE="${CONFIG_NAMESPACE}" \
        K3S_IMPORT_NODES="${CONFIG_IMPORT_NODES}" \
        "${SYSTEM_ROOT}/scripts/import-k3s-image.sh" "${CONFIG_IMAGE_LOCAL}"
}

build_production_image() {
    echo "Building ${CONFIG_COMPOSE_SERVICE} for production..."
    docker compose -f "${CONFIG_COMPOSE_FILE}" build "${CONFIG_COMPOSE_SERVICE}"
    compose_image="$(grep -E '^    image:' "${CONFIG_COMPOSE_FILE}" | head -1 | awk '{print $2}')"
    production_image="${CONFIG_IMAGE_REGISTRY}:${CONFIG_IMAGE_TAG}"
    docker tag "${compose_image}" "${production_image}"
    if [ "${CONFIG_REGISTRY_PUSH}" = "True" ]; then
        echo "Pushing ${production_image}..."
        docker push "${production_image}"
    else
        echo "Skipping push (build.registry.push is false)"
    fi
}

run_verify() {
    python3 - "${CONFIG_JSON}" <<'PY'
import json
import subprocess
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
    request = urllib.request.Request(url, method="GET")
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

deploy() {
    load_config
    python3 "${LIB}" "${APP}" validate

    if ! kubectl_cmd cluster-info >/dev/null 2>&1; then
        echo "Cannot reach Kubernetes cluster" >&2
        exit 1
    fi

    if [ "${CONFIG_OVERLAY}" = "homelab" ]; then
        build_homelab_image
    elif [ "${CONFIG_OVERLAY}" = "production" ]; then
        build_production_image
    fi

    echo "Applying overlay '${CONFIG_OVERLAY}' to namespace '${CONFIG_NAMESPACE}'..."
    apply_manifests

    echo "Waiting for rollout of deployment/${CONFIG_DEPLOYMENT}..."
    kubectl_cmd -n "${CONFIG_NAMESPACE}" rollout status "deployment/${CONFIG_DEPLOYMENT}" --timeout=300s
    kubectl_cmd -n "${CONFIG_NAMESPACE}" get pods,svc -o wide

    if [ "${SKIP_VERIFY:-}" != "1" ]; then
        echo "Running verify checks..."
        run_verify
    fi
}

case "${COMMAND}" in
    deploy) deploy ;;
    validate) python3 "${LIB}" "${APP}" validate ;;
    diff)
        load_config
        kustomize_build | kubectl_cmd diff -f - || true
        ;;
    delete)
        load_config
        kustomize_build | kubectl_cmd delete -f - --ignore-not-found
        ;;
    status)
        load_config
        kubectl_cmd -n "${CONFIG_NAMESPACE}" get all,configmap
        ;;
    verify)
        load_config
        run_verify
        ;;
    -h|--help|help) usage ;;
    *)
        echo "Unknown command: ${COMMAND}" >&2
        usage
        exit 1
        ;;
esac
