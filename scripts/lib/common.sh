#!/usr/bin/env bash
# common.sh - shared helpers sourced by every script in this repo.
# Provides: colored logging, prompts, dependency checks, env loading, a kubectl wrapper.

set -euo pipefail

# ---- paths -----------------------------------------------------------------
# Resolve the repo root no matter where a script is invoked from.
_COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${_COMMON_DIR}/../.." && pwd)"
export REPO_ROOT

# ---- colors ----------------------------------------------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[0;31m'; C_GRN=$'\033[0;32m'; C_YEL=$'\033[0;33m'
  C_BLU=$'\033[0;36m'; C_BLD=$'\033[1m'; C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_BLD=""; C_DIM=""; C_RST=""
fi

# ---- logging ---------------------------------------------------------------
info()  { printf "%s::%s %s\n" "$C_BLU" "$C_RST" "$*"; }
ok()    { printf "%s ok%s %s\n" "$C_GRN" "$C_RST" "$*"; }
warn()  { printf "%s warn%s %s\n" "$C_YEL" "$C_RST" "$*" >&2; }
err()   { printf "%s err%s %s\n" "$C_RED" "$C_RST" "$*" >&2; }
die()   { err "$*"; exit 1; }
hr()    { printf "%s%s%s\n" "$C_DIM" "------------------------------------------------------------" "$C_RST"; }
title() { printf "\n%s%s%s\n" "$C_BLD" "$*" "$C_RST"; hr; }

# ---- helpers ---------------------------------------------------------------
require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: '$1'. Install it and re-run."
}

confirm() {
  local prompt="${1:-Continue?}"
  if [[ "${ASSUME_YES:-}" == "1" ]]; then return 0; fi
  local ans
  read -r -p "$prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

is_root() { [[ "$(id -u)" -eq 0 ]]; }

# Run a command with sudo only if we are not already root.
maybe_sudo() {
  if is_root; then "$@"; else sudo "$@"; fi
}

# Load config/cluster.env into the environment.
load_env() {
  local f="${1:-${REPO_ROOT}/config/cluster.env}"
  if [[ ! -f "$f" ]]; then
    die "Config not found: $f
    Copy the template first:  cp config/cluster.env.example config/cluster.env
    then edit it to match your setup."
  fi
  set -a; # shellcheck disable=SC1090
  source "$f"; set +a
}

# Pick the best available kubeconfig: explicit env > user config > k3s server config.
# This lets the scripts work on a fresh server even before 'make kubeconfig'.
_pick_kubeconfig() {
  if [[ -n "${KUBECONFIG:-}" && -r "${KUBECONFIG}" ]]; then echo "${KUBECONFIG}"; return; fi
  if [[ -r "$HOME/.kube/config" ]]; then echo "$HOME/.kube/config"; return; fi
  if [[ -r /etc/rancher/k3s/k3s.yaml ]]; then echo /etc/rancher/k3s/k3s.yaml; return; fi
  echo "$HOME/.kube/config"
}

# Friendly kubectl wrapper that always targets the right kubeconfig.
kc() {
  local kcfg; kcfg="$(_pick_kubeconfig)"
  if command -v kubectl >/dev/null 2>&1; then
    KUBECONFIG="$kcfg" kubectl "$@"
  elif command -v k3s >/dev/null 2>&1; then
    maybe_sudo k3s kubectl "$@"
  else
    die "Neither kubectl nor k3s found on this machine."
  fi
}

# Verify we can actually reach a cluster before doing cluster work.
require_cluster() {
  kc version --request-timeout=5s >/dev/null 2>&1 || die "Can't reach a Kubernetes cluster.
    If this is the control-plane node, run 'make kubeconfig' first.
    If this is your laptop, copy the kubeconfig from the server (see docs/02-install-walkthrough.md)."
}

# Sanitize a string into a valid Kubernetes label value.
sanitize_label() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -e 's/[^a-z0-9._-]/-/g' -e 's/^-*//' -e 's/-*$//' | cut -c1-63
}
