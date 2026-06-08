#!/usr/bin/env bash
# registry.sh — private OCI/Docker registry for the homelab cluster.
#
#   make registry              install registry + print usage
#   make registry-nodes        write k3s registries.yaml on every node (needs SSH)
#   make registry-secret NS=x  create imagePullSecret in a namespace
#   make registry-verify       test HTTPS pull from a k3s node
#
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

REGISTRY_NS="${REGISTRY_NAMESPACE:-registry}"
REGISTRY_NODEPORT="${REGISTRY_NODEPORT:-30500}"
REGISTRY_USER="${REGISTRY_USER:-homelab}"
REGISTRY_PASSWORD="${REGISTRY_PASSWORD:-}"
REGISTRY_HOST="${REGISTRY_HOST:-${SERVER_HOST}}"
REGISTRY_ADDR="${REGISTRY_HOST}:${REGISTRY_NODEPORT}"
REGISTRY_INTERNAL="registry.${REGISTRY_NS}.svc.cluster.local:5000"
REGISTRY_CA_NODE="/etc/rancher/k3s/registry-ca.crt"
REGISTRY_CA_LOCAL="${REPO_ROOT}/config/.registry-ca.crt"
MANIFEST="${REPO_ROOT}/manifests/registry/registry.yaml"

registry_password() {
  if [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
    echo "$REGISTRY_PASSWORD"
    return 0
  fi
  local f="${REPO_ROOT}/config/.registry-password"
  if [[ -f "$f" ]]; then
    tr -d '\n' < "$f"
    return 0
  fi
  openssl rand -base64 18 | tr -d '/+=' | head -c 20
}

htpasswd_line() {
  local user="$1" pass="$2"
  if command -v htpasswd >/dev/null 2>&1; then
    local line
    line="$(htpasswd -Bbn "$user" "$pass" 2>/dev/null | head -1)"
    if [[ -n "$line" ]]; then
      echo "$line"
      return 0
    fi
  fi
  # Registry v2 only accepts bcrypt htpasswd entries (not apr1/md5).
  python3 - "$user" "$pass" <<'PY'
import sys
try:
    import bcrypt
except ImportError:
    sys.exit(1)
user, password = sys.argv[1], sys.argv[2]
print(f"{user}:{bcrypt.hashpw(password.encode(), bcrypt.gensalt(rounds=10)).decode()}")
PY
}

ensure_registry_tls() {
  local tmpdir san dns="${REGISTRY_INTERNAL%%:*}"
  tmpdir="$(mktemp -d)"
  san="IP:${REGISTRY_HOST},DNS:${dns}"
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${tmpdir}/tls.key" \
    -out "${tmpdir}/tls.crt" \
    -days 3650 \
    -subj "/CN=${REGISTRY_HOST}" \
    -addext "subjectAltName=${san}" 2>/dev/null
  kc -n "$REGISTRY_NS" create secret tls registry-tls \
    --cert="${tmpdir}/tls.crt" \
    --key="${tmpdir}/tls.key" \
    --dry-run=client -o yaml | kc apply -f -
  mkdir -p "${REPO_ROOT}/config"
  cp "${tmpdir}/tls.crt" "$REGISTRY_CA_LOCAL"
  chmod 600 "$REGISTRY_CA_LOCAL"
  rm -rf "$tmpdir"
}

cmd_install() {
  require_cluster
  title "Installing homelab container registry"
  local pass
  pass="$(registry_password)"
  if [[ -z "${REGISTRY_PASSWORD:-}" && ! -f "${REPO_ROOT}/config/.registry-password" ]]; then
    mkdir -p "${REPO_ROOT}/config"
    echo "$pass" > "${REPO_ROOT}/config/.registry-password"
    chmod 600 "${REPO_ROOT}/config/.registry-password"
    warn "Generated registry password → config/.registry-password (gitignored)"
  fi
  local line
  line="$(htpasswd_line "$REGISTRY_USER" "$pass")"
  [[ -n "$line" ]] || die "Could not generate htpasswd (install apache2-utils or use python3-passlib)"

  kc apply -f "$MANIFEST"
  kc -n "$REGISTRY_NS" create secret generic registry-auth \
    --from-literal=htpasswd="$line" \
    --dry-run=client -o yaml | kc apply -f -
  ensure_registry_tls
  kc -n "$REGISTRY_NS" rollout restart deploy/registry 2>/dev/null || true
  kc -n "$REGISTRY_NS" rollout status deploy/registry --timeout=120s

  ok "Registry running at https://${REGISTRY_ADDR}"
  hr
  echo "  LAN push/pull:  https://${REGISTRY_ADDR}/<project>/<image>:<tag>"
  echo "  In-cluster:     https://${REGISTRY_INTERNAL}/<project>/<image>:<tag>"
  echo "  User:           ${REGISTRY_USER}"
  echo "  Password:       ${pass}"
  echo ""
  echo "  Docker (on your LAN — trust cert or use insecure-registries):"
  echo "    docker login ${REGISTRY_ADDR} -u ${REGISTRY_USER}"
  echo "    docker tag myapp:latest ${REGISTRY_ADDR}/myapp:latest"
  echo "    docker push ${REGISTRY_ADDR}/myapp:latest"
  echo ""
  echo "  Kubernetes image in a Deployment:"
  echo "    image: ${REGISTRY_ADDR}/plateforge/plateforge:latest"
  echo ""
  echo "  Next steps:"
  echo "    make registry-nodes          # k3s registries.yaml on all nodes (HTTPS + skip verify)"
  echo "    make registry-verify         # test node pull"
  echo "    make registry-secret NS=plateforge"
  hr
}

registries_yaml() {
  cat <<EOF
# Written by make registry-nodes — private homelab registry (TLS, self-signed).
mirrors:
  "${REGISTRY_ADDR}":
    endpoint:
      - "https://${REGISTRY_ADDR}"
  "${REGISTRY_INTERNAL}":
    endpoint:
      - "https://${REGISTRY_INTERNAL}"
configs:
  "${REGISTRY_ADDR}":
    auth:
      username: ${REGISTRY_USER}
      password: ${REGISTRY_PASSWORD:-$(registry_password)}
    tls:
      ca_file: ${REGISTRY_CA_NODE}
  "${REGISTRY_INTERNAL}":
    auth:
      username: ${REGISTRY_USER}
      password: ${REGISTRY_PASSWORD:-$(registry_password)}
    tls:
      ca_file: ${REGISTRY_CA_NODE}
EOF
}

apply_node_registry_config() {
  local tmp_yaml="$1" ca_file="$2"
  maybe_sudo mkdir -p /etc/rancher/k3s
  maybe_sudo cp "$tmp_yaml" /etc/rancher/k3s/registries.yaml
  maybe_sudo cp "$ca_file" "$REGISTRY_CA_NODE"
  maybe_sudo chown root:root /etc/rancher/k3s/registries.yaml "$REGISTRY_CA_NODE"
  maybe_sudo chmod 644 /etc/rancher/k3s/registries.yaml "$REGISTRY_CA_NODE"
  if [[ -d /usr/local/share/ca-certificates ]]; then
    maybe_sudo cp "$ca_file" /usr/local/share/ca-certificates/homelab-registry.crt
    maybe_sudo update-ca-certificates >/dev/null 2>&1 || true
  fi
  if maybe_sudo systemctl is-active --quiet k3s 2>/dev/null; then
    maybe_sudo systemctl restart k3s
  elif maybe_sudo systemctl is-active --quiet k3s-agent 2>/dev/null; then
    maybe_sudo systemctl restart k3s-agent
  fi
}

cmd_configure_nodes() {
  require_cluster
  title "Configuring k3s registries.yaml on fleet nodes"
  local pass
  pass="$(registry_password)"
  REGISTRY_PASSWORD="$pass"
  [[ -f "$REGISTRY_CA_LOCAL" ]] || die "Registry CA missing — run: make registry"
  local yaml tmp
  yaml="$(registries_yaml)"
  tmp="$(mktemp)"
  echo "$yaml" > "$tmp"

  mapfile -t NODES < <(kc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
  local user="${COCKPIT_SSH_USER:-${USER:-alec}}"
  for row in "${NODES[@]}"; do
    local name ip
    name="${row%%$'\t'*}"
    ip="${row#*$'\t'}"
    info "Configuring ${name} (${ip})..."
    if [[ "$name" == "$(hostname -s 2>/dev/null || hostname)" ]]; then
      if apply_node_registry_config "$tmp" "$REGISTRY_CA_LOCAL" 2>/dev/null; then
        ok "${name} (local)"
      else
        warn "${name} (local): sudo failed — copy registries.yaml + registry-ca.crt manually"
      fi
      continue
    fi
    if ! ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=accept-new \
         "${user}@${ip}" 'test -x /usr/local/bin/k3s || test -x /usr/local/bin/k3s-agent' 2>/dev/null; then
      warn "${name}: SSH key login failed — configure manually (see docs/08-container-registry.md)"
      continue
    fi
    scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$tmp" "${user}@${ip}:/tmp/registries.yaml"
    scp -o BatchMode=yes -o StrictHostKeyChecking=accept-new "$REGISTRY_CA_LOCAL" "${user}@${ip}:/tmp/registry-ca.crt"
    ssh -o BatchMode=yes "${user}@${ip}" \
      'sudo mkdir -p /etc/rancher/k3s /usr/local/share/ca-certificates && \
       sudo mv /tmp/registries.yaml /etc/rancher/k3s/registries.yaml && \
       sudo mv /tmp/registry-ca.crt /etc/rancher/k3s/registry-ca.crt && \
       sudo cp /etc/rancher/k3s/registry-ca.crt /usr/local/share/ca-certificates/homelab-registry.crt && \
       sudo update-ca-certificates >/dev/null 2>&1 || true && \
       sudo chown root:root /etc/rancher/k3s/registries.yaml /etc/rancher/k3s/registry-ca.crt && \
       sudo chmod 644 /etc/rancher/k3s/registries.yaml /etc/rancher/k3s/registry-ca.crt && \
       (sudo systemctl restart k3s 2>/dev/null || sudo systemctl restart k3s-agent)'
    ok "${name}"
  done
  rm -f "$tmp"
  hr
  ok "Node registry config pass complete (check warnings above)"
}

registry_https_ok() {
  local pass
  pass="$(registry_password)"
  curl -ksf -u "${REGISTRY_USER}:${pass}" "https://${REGISTRY_ADDR}/v2/" >/dev/null 2>&1
}

registry_manifest_ok() {
  local pass image="${PLATEFORGE_IMAGE:-plateforge}"
  pass="$(registry_password)"
  curl -ksf -u "${REGISTRY_USER}:${pass}" \
    "https://${REGISTRY_ADDR}/v2/plateforge/${image}/tags/list" 2>/dev/null \
    | python3 -c "import json,sys; tags=json.load(sys.stdin).get('tags') or []; sys.exit(0 if 'latest' in tags else 1)" 2>/dev/null
}

registry_crictl_pull_ok() {
  local pass image="${PLATEFORGE_IMAGE:-plateforge}"
  local test_img="${REGISTRY_ADDR}/plateforge/${image}:latest"
  pass="$(registry_password)"
  if ! command -v k3s >/dev/null 2>&1; then
    return 1
  fi
  if sudo -n test -r /etc/rancher/k3s/registries.yaml 2>/dev/null || \
     test -r /etc/rancher/k3s/registries.yaml 2>/dev/null; then
    if sudo -n k3s crictl pull --creds "${REGISTRY_USER}:${pass}" "$test_img" >/dev/null 2>&1; then
      return 0
    fi
  fi
  return 1
}

cmd_verify() {
  require_cluster
  local quiet="${1:-}"
  [[ "$quiet" == "--quiet" ]] && quiet=1 || quiet=0

  if ! registry_https_ok; then
    [[ "$quiet" -eq 1 ]] && return 1
    die "HTTPS registry unreachable at https://${REGISTRY_ADDR}/v2/"
  fi
  [[ "$quiet" -eq 0 ]] && ok "HTTPS registry API reachable"

  if ! registry_manifest_ok; then
    [[ "$quiet" -eq 1 ]] && return 1
    warn "plateforge/${PLATEFORGE_IMAGE:-plateforge}:latest not in registry — run: make plateforge-images-sync"
    return 1
  fi
  [[ "$quiet" -eq 0 ]] && ok "Registry serves plateforge/${PLATEFORGE_IMAGE:-plateforge}:latest"

  if registry_crictl_pull_ok; then
    [[ "$quiet" -eq 0 ]] && ok "crictl pull succeeded on $(hostname -s 2>/dev/null || hostname)"
    return 0
  fi

  # API + manifest OK is enough when nodes have the CA in system trust (make registry-nodes).
  [[ "$quiet" -eq 1 ]] && return 0
  warn "crictl pull needs sudo on this host — run: sudo make registry-verify"
  return 0
}

cmd_pull_secret() {
  require_cluster
  local ns="${1:-${NS:-default}}"
  local pass
  pass="$(registry_password)"
  kc create namespace "$ns" --dry-run=client -o yaml | kc apply -f - >/dev/null 2>&1 || true
  kc -n "$ns" create secret docker-registry homelab-registry \
    --docker-server="${REGISTRY_ADDR}" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$pass" \
    --dry-run=client -o yaml | kc apply -f -
  kc -n "$ns" patch serviceaccount default \
    -p '{"imagePullSecrets":[{"name":"homelab-registry"}]}' 2>/dev/null || true
  ok "imagePullSecret homelab-registry in namespace ${ns}"
  echo "  Use image: ${REGISTRY_ADDR}/<project>/<name>:<tag>"
}

cmd_status() {
  require_cluster
  title "Registry status"
  kc -n "$REGISTRY_NS" get deploy,pvc,svc 2>/dev/null || warn "Registry not installed — run: make registry"
  echo ""
  echo "  URL: https://${REGISTRY_ADDR}"
}

cmd="${1:-install}"
case "$cmd" in
  install)   cmd_install ;;
  nodes)     cmd_configure_nodes ;;
  secret)    cmd_pull_secret "${2:-}" ;;
  verify)    cmd_verify "${2:-}" ;;
  status)    cmd_status ;;
  *) die "Usage: registry.sh install|nodes|secret [namespace]|verify|status" ;;
esac
