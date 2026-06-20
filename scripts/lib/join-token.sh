#!/usr/bin/env bash
# join-token.sh — fetch the k3s cluster join token for Fleet Command / add-node flows.
# Tries local file, cluster.env JOIN_TOKEN, SSH to SERVER_HOST, then a one-shot
# pod on the control-plane node (works from a laptop with kubeconfig only).

_fetch_join_token_local() {
  local tf=/var/lib/rancher/k3s/server/node-token
  if [[ -r "$tf" ]]; then cat "$tf"; return 0; fi
  if maybe_sudo test -r "$tf" 2>/dev/null; then maybe_sudo cat "$tf"; return 0; fi
  return 1
}

_fetch_join_token_ssh() {
  local host="${1:-}" user="${2:-}"
  [[ -z "$host" ]] && return 1
  local tok u
  for u in "$user" "${USER:-}" root; do
    [[ -z "$u" ]] && continue
    tok="$(ssh -o BatchMode=yes -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new \
          "${u}@${host}" 'sudo cat /var/lib/rancher/k3s/server/node-token 2>/dev/null' 2>/dev/null)" || true
    [[ -n "$tok" ]] && echo "$tok" && return 0
  done
  return 1
}

_fetch_join_token_pod() {
  local cp
  cp="$(kc get nodes -l 'node-role.kubernetes.io/control-plane' -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)" || true
  if [[ -z "$cp" ]]; then
    cp="$(kc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.metadata.labels.node-role\.homelab/control-plane}{"\n"}{end}' 2>/dev/null \
        | awk '$2=="true"{print $1; exit}')" || true
  fi
  [[ -z "$cp" ]] && return 1
  kc create namespace cockpit --dry-run=client -o yaml | kc apply -f - >/dev/null 2>&1 || true
  kc -n cockpit delete pod cockpit-token-fetch --ignore-not-found >/dev/null 2>&1 || true
  kc -n cockpit apply -f - >/dev/null <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: cockpit-token-fetch
  namespace: cockpit
spec:
  nodeName: ${cp}
  restartPolicy: Never
  tolerations:
    - key: node-role.kubernetes.io/control-plane
      operator: Exists
      effect: NoSchedule
    - key: node-role.kubernetes.io/etcd
      operator: Exists
      effect: NoSchedule
  containers:
    - name: fetch
      image: busybox:1.36
      command: ["cat", "/host/token"]
      volumeMounts:
        - name: host
          mountPath: /host
          readOnly: true
  volumes:
    - name: host
      hostPath:
        path: /var/lib/rancher/k3s/server
        type: Directory
EOF
  if ! kc -n cockpit wait --for=jsonpath='{.status.phase}'=Succeeded pod/cockpit-token-fetch --timeout=45s >/dev/null 2>&1; then
    kc -n cockpit delete pod cockpit-token-fetch --ignore-not-found >/dev/null 2>&1 || true
    return 1
  fi
  kc -n cockpit logs cockpit-token-fetch 2>/dev/null
  kc -n cockpit delete pod cockpit-token-fetch --ignore-not-found >/dev/null 2>&1 || true
}

_fetch_join_token_existing() {
  kc -n cockpit get secret cockpit-join -o jsonpath='{.data.token}' 2>/dev/null | base64 -d
}

# Print token to stdout; return 0 on success.
fetch_join_token() {
  local tok=""
  if [[ -n "${JOIN_TOKEN:-}" ]]; then echo "$JOIN_TOKEN"; return 0; fi
  tok="$(_fetch_join_token_local 2>/dev/null)" && [[ -n "$tok" ]] && echo "$tok" && return 0
  if [[ -n "${SERVER_HOST:-}" ]]; then
    tok="$(_fetch_join_token_ssh "${SERVER_HOST}" "${COCKPIT_SSH_USER:-}")" && [[ -n "$tok" ]] && echo "$tok" && return 0
  fi
  tok="$(_fetch_join_token_pod 2>/dev/null)" && [[ -n "$tok" ]] && echo "$tok" && return 0
  tok="$(_fetch_join_token_existing 2>/dev/null)" && [[ -n "$tok" ]] && echo "$tok" && return 0
  return 1
}
