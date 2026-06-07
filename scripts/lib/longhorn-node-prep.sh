#!/usr/bin/env bash
# longhorn-node-prep.sh - host prerequisites for Longhorn storage on k3s nodes.
# Sourced by install/join scripts. Requires common.sh (maybe_sudo, info, ok, warn).

# Longhorn manager pods need iscsi tools on every node that runs the daemonset.
_LONGHORN_APT_PACKAGES=( open-iscsi nfs-common )

longhorn_host_has_docker() {
  systemctl is-active --quiet docker 2>/dev/null
}

longhorn_host_needs_systemd_cgroups() {
  # Standalone Docker on the host uses systemd cgroups; k3s must match or some
  # pods (e.g. longhorn-manager) fail with "expected cgroupsPath ... systemd cgroups".
  longhorn_host_has_docker
}

longhorn_k3s_config_path() {
  echo /etc/rancher/k3s/config.yaml
}

longhorn_k3s_has_systemd_cgroups() {
  local cfg
  cfg="$(longhorn_k3s_config_path)"
  [[ -f "$cfg" ]] && grep -q 'cgroup-driver=systemd' "$cfg"
}

ensure_longhorn_host_packages() {
  local missing=() pkg
  for pkg in "${_LONGHORN_APT_PACKAGES[@]}"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=( "$pkg" )
  done
  if [[ "${#missing[@]}" -eq 0 ]]; then
    ok "Longhorn host packages present (${_LONGHORN_APT_PACKAGES[*]})"
    return 0
  fi

  info "Installing Longhorn host packages: ${missing[*]}"
  maybe_sudo apt-get update || warn "apt-get update reported errors; continuing with package install"
  maybe_sudo apt-get install -y "${missing[@]}"
  maybe_sudo systemctl enable iscsid
  maybe_sudo systemctl restart iscsid
  command -v iscsiadm >/dev/null 2>&1 || die "iscsiadm missing after installing open-iscsi"
  ok "Longhorn host packages installed"
}

ensure_longhorn_data_dir() {
  maybe_sudo mkdir -p /var/lib/longhorn
  ok "Longhorn data directory ready (/var/lib/longhorn)"
}

ensure_k3s_systemd_cgroups() {
  longhorn_host_needs_systemd_cgroups || return 0
  longhorn_k3s_has_systemd_cgroups && return 0

  local cfg dir
  cfg="$(longhorn_k3s_config_path)"
  dir="$(dirname "$cfg")"
  info "Docker detected — configuring k3s to use systemd cgroups (${cfg})"
  maybe_sudo mkdir -p "$dir"
  if [[ -f "$cfg" ]]; then
    maybe_sudo cp "$cfg" "${cfg}.bak.$(date +%s)"
    warn "Backed up existing k3s config before adding cgroup-driver=systemd"
  fi
  maybe_sudo tee "$cfg" >/dev/null <<'EOF'
kubelet-arg:
  - "cgroup-driver=systemd"
EOF
  ok "k3s cgroup-driver=systemd configured (required when Docker runs on the host)"
}

prep_longhorn_node_host() {
  title "Preparing host for Longhorn storage"
  ensure_longhorn_host_packages
  ensure_longhorn_data_dir
  ensure_k3s_systemd_cgroups
}

check_longhorn_host_preflight() {
  # Called from preflight.sh — report only, no installs.
  local note=0
  for pkg in "${_LONGHORN_APT_PACKAGES[@]}"; do
    if ! dpkg -s "$pkg" >/dev/null 2>&1; then
      warn "Package '$pkg' not installed (Longhorn needs it). Run 'make agent' / join scripts install it automatically."
      note=1
    fi
  done
  [[ "$note" -eq 0 ]] && ok "Longhorn host packages present (${_LONGHORN_APT_PACKAGES[*]})"

  if longhorn_host_needs_systemd_cgroups && ! longhorn_k3s_has_systemd_cgroups; then
    warn "Docker is running but k3s is not configured with cgroup-driver=systemd.
       Longhorn pods may crash-loop until join scripts apply the fix (or you add it to $(longhorn_k3s_config_path))."
  elif longhorn_host_needs_systemd_cgroups; then
    ok "k3s systemd cgroup config present (Docker + k3s coexistence)"
  fi
}
