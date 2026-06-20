#!/usr/bin/env bash
# bootstrap-stack.sh - RUN ON A SERVER/laptop. Installs the GPU + storage + monitoring
# stack with Helm. Idempotent: re-running upgrades in place. Components are toggled
# in config/cluster.env (INSTALL_* flags).
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
load_env
require_cluster

# --- ensure helm ------------------------------------------------------------
if ! command -v helm >/dev/null 2>&1; then
  info "Installing Helm..."
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi
ok "helm: $(helm version --short 2>/dev/null || echo present)"

helm repo add nvidia    https://helm.ngc.nvidia.com/nvidia        >/dev/null 2>&1 || true
helm repo add longhorn  https://charts.longhorn.io                >/dev/null 2>&1 || true
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null
ok "Helm repos ready"

ver_flag() { [[ -n "$1" ]] && echo "--version $1" || true; }

# --- GPU Operator -----------------------------------------------------------
if [[ "${INSTALL_GPU_OPERATOR}" == "1" ]]; then
  title "Installing NVIDIA GPU Operator"
  EXTRA=""
  if [[ "${GPU_OPERATOR_MANAGES_DRIVER}" == "1" ]]; then
    EXTRA="--set driver.enabled=true"
    info "GPU Operator WILL manage the NVIDIA driver."
  else
    EXTRA="--set driver.enabled=false"
    info "GPU Operator will use the HOST's pre-installed driver."
  fi
  # shellcheck disable=SC2046
  helm upgrade --install gpu-operator nvidia/gpu-operator \
    -n gpu-operator --create-namespace \
    $(ver_flag "${GPU_OPERATOR_VERSION}") \
    -f "${REPO_ROOT}/manifests/gpu-operator/values.yaml" \
    $EXTRA --wait --timeout 12m
  ok "GPU Operator installed."
fi

# --- NVIDIA DRA driver (per-GPU targeting) ----------------------------------
if [[ "${INSTALL_DRA_DRIVER}" == "1" ]]; then
  title "Installing NVIDIA DRA Driver for GPUs"
  warn "Requires Kubernetes >= 1.34. This driver is newer — test before trusting it with prod traffic."
  # shellcheck disable=SC2046
  helm upgrade --install nvidia-dra-driver nvidia/nvidia-dra-driver-gpu \
    -n nvidia-dra-driver-gpu --create-namespace \
    $(ver_flag "${NVIDIA_DRA_VERSION}") \
    --set resources.gpus.enabled=true \
    --wait --timeout 8m || warn "DRA driver install hit an issue — see docs/05-troubleshooting.md. Cluster still works via node labels."
  info "Applying DeviceClasses (training / inference)..."
  kc apply -f "${REPO_ROOT}/manifests/dra/" || warn "DeviceClass apply failed; check 'kubectl api-resources | grep resource.k8s.io'."
  ok "DRA driver + DeviceClasses applied."
fi

# --- Longhorn ---------------------------------------------------------------
if [[ "${INSTALL_LONGHORN}" == "1" ]]; then
  title "Installing Longhorn (replicated storage)"
  # shellcheck disable=SC2046
  helm upgrade --install longhorn longhorn/longhorn \
    -n longhorn-system --create-namespace \
    $(ver_flag "${LONGHORN_VERSION}") \
    -f "${REPO_ROOT}/manifests/storage/longhorn-values.yaml" \
    --wait --timeout 10m
  ok "Longhorn installed. It is now your default StorageClass."
fi

# --- Monitoring -------------------------------------------------------------
if [[ "${INSTALL_MONITORING}" == "1" ]]; then
  title "Installing kube-prometheus-stack (Prometheus + Grafana)"
  # shellcheck disable=SC2046
  helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    $(ver_flag "${MONITORING_VERSION}") \
    -f "${REPO_ROOT}/manifests/monitoring/values.yaml" \
    --wait --timeout 10m
  ok "Monitoring installed."
  echo "Open Grafana:  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80"
  echo "  user: admin   pass: kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d"
fi

# --- Headlamp web GUI -------------------------------------------------------
if [[ "${INSTALL_DASHBOARD:-0}" == "1" ]]; then
  "${REPO_ROOT}/scripts/dashboard.sh" install
fi

# --- Fleet Command (GPU-centric management GUI) ------------------------------
if [[ "${INSTALL_COCKPIT:-0}" == "1" ]]; then
  "${REPO_ROOT}/scripts/cockpit.sh" install
fi

# --- Private container registry ---------------------------------------------
if [[ "${INSTALL_REGISTRY:-0}" == "1" ]]; then
  "${REPO_ROOT}/scripts/registry.sh" install
fi

hr
ok "Stack bootstrap complete. Run 'make label-gpus' then 'make status'."
