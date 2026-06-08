#!/bin/bash
# Import a local Docker image into k3s containerd on the server and worker nodes.

set -euo pipefail

IMAGE="${1:?Usage: import-k3s-image.sh <image:tag>}"
IMPORT_NODES="${K3S_IMPORT_NODES:-homelab/cpu-tier=cheap}"
NAMESPACE="${K3S_IMPORT_NAMESPACE:-plateforge}"

import_on_server() {
    local k3s_pid
    k3s_pid="$(pgrep -n -f 'k3s server' || true)"
    if [ -z "${k3s_pid}" ]; then
        echo "k3s server process not found" >&2
        exit 1
    fi

    echo "Importing ${IMAGE} into k3s server (pid ${k3s_pid})..."
    docker save "${IMAGE}" | docker run --rm -i --privileged --pid host alpine \
        nsenter -t "${k3s_pid}" -m -u -i -n -p sh -c \
        'cat > /tmp/app.tar && /usr/local/bin/k3s ctr -n k8s.io images import /tmp/app.tar && rm /tmp/app.tar'
}

import_on_node() {
    local node="$1"
    local tar_file="$2"

    echo "Importing ${IMAGE} onto node ${node}..."
    kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: image-import-${node}
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

    kubectl -n "${NAMESPACE}" wait --for=condition=Ready "pod/image-import-${node}" --timeout=120s
    kubectl -n "${NAMESPACE}" cp "${tar_file}" "${NAMESPACE}/image-import-${node}:/host/tmp/app.tar"
    kubectl -n "${NAMESPACE}" exec "image-import-${node}" -- \
        chroot /host sh -c '/usr/local/bin/k3s ctr -n k8s.io images import /tmp/app.tar && rm /tmp/app.tar'
    kubectl -n "${NAMESPACE}" delete pod "image-import-${node}" --wait=false
}

import_on_server

if [ -n "${IMPORT_NODES}" ] && command -v kubectl >/dev/null 2>&1; then
    IFS=',' read -r label_key label_value <<< "${IMPORT_NODES}"
    mapfile -t nodes < <(kubectl get nodes -l "${label_key}=${label_value}" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')
    if [ "${#nodes[@]}" -gt 0 ]; then
        tar_file="$(mktemp /tmp/k3s-image-XXXXXX.tar)"
        trap 'rm -f "${tar_file}"' EXIT
        docker save "${IMAGE}" -o "${tar_file}"
        for node in "${nodes[@]}"; do
            import_on_node "${node}" "${tar_file}"
        done
    fi
fi

echo "Done: ${IMAGE}"
