#!/bin/bash
# Deploy a registered homelab app: docker compose build, k3s import, kustomize apply.

set -euo pipefail

SYSTEM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${1:-plateforge}"
COMMAND="${2:-deploy}"

export KUBECONFIG="${KUBECONFIG:-${HOME}/.kube/config}"

read_app_yaml() {
    local key="$1"
    python3 - "${SYSTEM_ROOT}/apps/${APP}.yaml" "${key}" <<'PY'
import sys
import yaml

data = yaml.safe_load(open(sys.argv[1]))
key = sys.argv[2]
value = data
for part in key.split("."):
    value = value[part]
print(value)
PY
}

REPO="$(read_app_yaml repo)"
REPO="${REPO/#\~/$HOME}"
NAMESPACE="$(read_app_yaml namespace)"
OVERLAY="${K8S_OVERLAY:-$(read_app_yaml k8s_overlay)}"
DEPLOYMENT="$(read_app_yaml deployment)"
IMAGE_LOCAL="$(read_app_yaml image_local)"
COMPOSE_SERVICE="$(read_app_yaml compose_service)"
IMAGE_TAG="${IMAGE_TAG:-latest}"

usage() {
    cat <<EOF
Usage: $0 <app> [deploy|diff|delete|status]

Registered apps: $(basename -a "${SYSTEM_ROOT}"/apps/*.yaml 2>/dev/null | sed 's/.yaml//')

Environment:
  K8S_OVERLAY     Kustomize overlay (default from apps/<app>.yaml)
  KUBECONFIG      kubeconfig path
  IMAGE_TAG       Registry tag for production overlay
  KUBECTL_CONTEXT optional kubectl context
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
    kubectl_cmd kustomize "${REPO}/k8s/overlays/${OVERLAY}" --load-restrictor LoadRestrictionsNone
}

build_homelab() {
    echo "Building ${COMPOSE_SERVICE} in ${REPO}..."
    docker compose -f "${REPO}/docker-compose.yml" build "${COMPOSE_SERVICE}"
    compose_image="$(grep -E '^    image:' "${REPO}/docker-compose.yml" | head -1 | awk '{print $2}')"
    docker tag "${compose_image}" "${IMAGE_LOCAL}"
    "${SYSTEM_ROOT}/scripts/import-k3s-image.sh" "${IMAGE_LOCAL}"
}

deploy() {
    if ! kubectl_cmd cluster-info >/dev/null 2>&1; then
        echo "Cannot reach Kubernetes cluster" >&2
        exit 1
    fi

    if [ "${OVERLAY}" = "homelab" ]; then
        build_homelab
    fi

    echo "Applying k8s/overlays/${OVERLAY} to namespace ${NAMESPACE}..."
    kustomize_build | kubectl_cmd apply -f -

    echo "Waiting for rollout..."
    kubectl_cmd -n "${NAMESPACE}" rollout status "deployment/${DEPLOYMENT}" --timeout=300s
    kubectl_cmd -n "${NAMESPACE}" get pods,svc
}

case "${COMMAND}" in
    deploy) deploy ;;
    diff)
        kustomize_build | kubectl_cmd diff -f - || true
        ;;
    delete)
        kustomize_build | kubectl_cmd delete -f - --ignore-not-found
        ;;
    status)
        kubectl_cmd -n "${NAMESPACE}" get all,configmap
        ;;
    -h|--help|help) usage ;;
    *)
        echo "Unknown command: ${COMMAND}" >&2
        usage
        exit 1
        ;;
esac
