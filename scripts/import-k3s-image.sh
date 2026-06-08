#!/usr/bin/env bash
# Import a local Docker image into k3s containerd on the server and worker nodes.

set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"

IMAGE="${1:?Usage: import-k3s-image.sh <image:tag> [namespace] [label=value]}"
NAMESPACE="${2:-${K3S_IMPORT_NAMESPACE:-default}}"
IMPORT_NODES="${3:-${K3S_IMPORT_NODES:-}}"

import_on_server() {
    local k3s_pid
    k3s_pid="$(pgrep -n -f 'k3s server' || true)"
    if [[ -z "${k3s_pid}" ]]; then
        die "k3s server process not found"
    fi

    info "Importing ${IMAGE} into k3s server (pid ${k3s_pid})..."
    docker save "${IMAGE}" | docker run --rm -i --privileged --pid host alpine \
        nsenter -t "${k3s_pid}" -m -u -i -n -p sh -c \
        'cat > /tmp/app.tar && /usr/local/bin/k3s ctr -n k8s.io images import /tmp/app.tar && rm /tmp/app.tar'
}

import_on_node() {
    local node="$1"
    local tar_file="$2"
    local pod="image-import-${node}-$(date +%s)"

    info "Importing ${IMAGE} onto node ${node}..."
    kc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${pod}
  namespace: ${NAMESPACE}
spec:
  nodeName: ${node}
  restartPolicy: Never
  hostPID: true
  containers:
    - name: import
      image: alpine:3.20
      securityContext:
        privileged: true
      command: ["sleep", "3600"]
      volumeMounts:
        - name: host
          mountPath: /host
  volumes:
    - name: host
      hostPath:
        path: /
EOF

    kc -n "${NAMESPACE}" wait --for=condition=Ready "pod/${pod}" --timeout=120s
    kc -n "${NAMESPACE}" cp "${tar_file}" "${NAMESPACE}/${pod}:/host/tmp/app.tar"
    kc -n "${NAMESPACE}" exec "${pod}" -- \
        chroot /host sh -c '/usr/local/bin/k3s ctr -n k8s.io images import /tmp/app.tar && rm /tmp/app.tar'
    kc -n "${NAMESPACE}" delete pod "${pod}" --wait=false
}

import_on_server

if [[ -n "${IMPORT_NODES}" ]]; then
    label_key="${IMPORT_NODES%%=*}"
    label_value="${IMPORT_NODES#*=}"
    [[ -n "${label_key}" && -n "${label_value}" ]] || die "Invalid import_nodes label (want key=value): ${IMPORT_NODES}"
    mapfile -t nodes < <(kc get nodes -l "${label_key}=${label_value}" \
        -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    if [[ "${#nodes[@]}" -gt 0 ]]; then
        tar_file="$(mktemp /tmp/k3s-image-XXXXXX.tar)"
        trap 'rm -f "${tar_file}"' EXIT
        docker save "${IMAGE}" -o "${tar_file}"
        for node in "${nodes[@]}"; do
            import_on_node "${node}" "${tar_file}"
        done
    else
        warn "No nodes match ${label_key}=${label_value} — image only on server"
    fi
fi

ok "Imported ${IMAGE}"
