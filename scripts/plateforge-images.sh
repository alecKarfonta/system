#!/usr/bin/env bash
# plateforge-images.sh — sync plateforge image and pick local registry vs GHCR.
#
#   make plateforge-images           # resolve + patch deployment (local if present, else GHCR)
#   make plateforge-images-sync      # copy GHCR -> homelab registry (skopeo Job)
#   make plateforge-images-resolve   # print chosen image ref only
#
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env

NS="${PLATEFORGE_NAMESPACE:-plateforge}"
IMAGE="${PLATEFORGE_IMAGE:-plateforge}"
DEPLOY="${PLATEFORGE_DEPLOY:-plateforge}"
CONTAINER="${PLATEFORGE_CONTAINER:-plateforge}"
GHCR="${PLATEFORGE_GHCR:-ghcr.io/aleckarfonta/electroplating/plateforge}"
REGISTRY_NS="${REGISTRY_NAMESPACE:-registry}"
REGISTRY_NODEPORT="${REGISTRY_NODEPORT:-30500}"
REGISTRY_USER="${REGISTRY_USER:-homelab}"
REGISTRY_HOST="${REGISTRY_HOST:-${SERVER_HOST}}"
REGISTRY_ADDR="${REGISTRY_HOST}:${REGISTRY_NODEPORT}"
REGISTRY_INTERNAL="registry.${REGISTRY_NS}.svc.cluster.local:5000"
TAG="${PLATEFORGE_TAG:-latest}"

registry_password() {
  if [[ -n "${REGISTRY_PASSWORD:-}" ]]; then
    echo "$REGISTRY_PASSWORD"
    return 0
  fi
  local f="${REPO_ROOT}/config/.registry-password"
  [[ -f "$f" ]] || die "Registry password missing — run: make registry"
  tr -d '\n' < "$f"
}

registry_curl() {
  local path="$1"
  local pass
  pass="$(registry_password)"
  curl -ksf -u "${REGISTRY_USER}:${pass}" "https://${REGISTRY_ADDR}${path}"
}

registry_has_image() {
  registry_curl "/v2/plateforge/${IMAGE}/tags/list" 2>/dev/null \
    | python3 -c "import json,sys; tags=json.load(sys.stdin).get('tags') or []; sys.exit(0 if '${TAG}' in tags else 1)" 2>/dev/null
}

registry_pull_ready() {
  "${REPO_ROOT}/scripts/registry.sh" verify --quiet 2>/dev/null
}

local_image() {
  echo "${REGISTRY_ADDR}/plateforge/${IMAGE}:${TAG}"
}

ghcr_image() {
  echo "${GHCR}:${TAG}"
}

resolve_image() {
  if registry_pull_ready && registry_has_image; then
    local_image
  else
    ghcr_image
  fi
}

image_source_label() {
  local img
  img="$(resolve_image)"
  if [[ "$img" == "${REGISTRY_ADDR}"* ]]; then
    echo "local registry"
  elif registry_has_image; then
    echo "GHCR (local present but node pull not verified — run: make registry-nodes && make registry-verify)"
  else
    echo "GHCR (not in local registry)"
  fi
}

cmd_resolve() {
  require_cluster
  title "Plateforge image resolution"
  local img src
  img="$(resolve_image)"
  src="$(image_source_label)"
  echo "  ${DEPLOY}: ${img}  # ${src}"
}

ensure_pull_secrets() {
  local ns="$1" pass secrets_json='[]'
  pass="$(registry_password)"
  kc create namespace "$ns" --dry-run=client -o yaml | kc apply -f - >/dev/null 2>&1 || true
  kc -n "$ns" create secret docker-registry homelab-registry \
    --docker-server="${REGISTRY_ADDR}" \
    --docker-username="$REGISTRY_USER" \
    --docker-password="$pass" \
    --dry-run=client -o yaml | kc apply -f - >/dev/null
  secrets_json='[{"name":"homelab-registry"}]'
  if [[ -n "${GHCR_TOKEN:-}" ]]; then
    kc -n "$ns" create secret docker-registry ghcr-io \
      --docker-server=ghcr.io \
      --docker-username="${GHCR_USER:-${USER:-aleckarfonta}}" \
      --docker-password="$GHCR_TOKEN" \
      --dry-run=client -o yaml | kc apply -f - >/dev/null
    secrets_json='[{"name":"homelab-registry"},{"name":"ghcr-io"}]'
  fi
  kc -n "$ns" patch serviceaccount default \
    --type merge -p "{\"imagePullSecrets\":${secrets_json}}" >/dev/null 2>&1 || true
}

cmd_secrets() {
  require_cluster
  ensure_pull_secrets "$NS"
  ok "Pull secrets updated in namespace ${NS}"
  if [[ -z "${GHCR_TOKEN:-}" ]]; then
    warn "GHCR_TOKEN not set — public GHCR pulls only (private repos need the token in cluster.env)"
  fi
}

cmd_apply() {
  require_cluster
  ensure_pull_secrets "$NS"
  title "Applying plateforge image (local registry preferred, GHCR fallback)"
  local img src
  img="$(resolve_image)"
  if [[ "$img" == "${REGISTRY_ADDR}"* ]]; then
    src="local"
  else
    src="ghcr"
  fi
  if ! kc -n "$NS" get deploy "$DEPLOY" >/dev/null 2>&1; then
    warn "Deployment ${DEPLOY} not found in ${NS} — skipping"
    return 0
  fi
  kc -n "$NS" set image "deploy/${DEPLOY}" "${CONTAINER}=${img}" >/dev/null
  ok "${DEPLOY} -> ${img} (${src})"
}

cmd_sync() {
  require_cluster
  local pass job_name="plateforge-sync-$(date +%s)"
  pass="$(registry_password)"
  title "Syncing plateforge image GHCR -> ${REGISTRY_ADDR}"
  if ! kc -n "$REGISTRY_NS" get deploy registry >/dev/null 2>&1; then
    die "Homelab registry not installed — run: make registry"
  fi
  if ! kc -n "$REGISTRY_NS" rollout status deploy/registry --timeout=30s >/dev/null 2>&1; then
    warn "Registry pod not ready — sync may fail until it is Running"
  fi

  local script
  script="echo '=== ${IMAGE} ==='; "
  script+="skopeo copy --override-os linux --override-arch amd64 "
  script+="docker://${GHCR}:${TAG} "
  script+="docker://${REGISTRY_INTERNAL}/plateforge/${IMAGE}:${TAG} "
  script+="--dest-creds ${REGISTRY_USER}:${pass} --dest-tls-verify=false"

  kc create job "$job_name" -n "$NS" \
    --image=quay.io/skopeo/stable:latest \
    -- sh -c "$script"
  info "Waiting for sync job ${job_name}..."
  if kc -n "$NS" wait --for=condition=complete "job/${job_name}" --timeout=900s; then
    ok "Sync complete"
    kc -n "$NS" logs "job/${job_name}" | tail -20
    kc -n "$NS" delete job "$job_name" --ignore-not-found >/dev/null
    info "Run: make registry-nodes && make registry-verify && make plateforge-images"
  else
    warn "Sync job failed — logs:"
    kc -n "$NS" logs "job/${job_name}" 2>/dev/null || true
    die "Sync failed (GHCR pull may need GHCR_TOKEN on private images)"
  fi
}

cmd="${1:-apply}"
case "$cmd" in
  resolve) cmd_resolve ;;
  secrets) cmd_secrets ;;
  apply)   cmd_apply ;;
  sync)    cmd_sync ;;
  *) die "Usage: plateforge-images.sh apply|resolve|sync|secrets" ;;
esac
