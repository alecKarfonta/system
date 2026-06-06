#!/usr/bin/env bash
# label-gpus.sh - RUN ON A SERVER/laptop. Auto-tag each node by GPU tier so you can
# target workloads with a simple nodeSelector. Reads NVIDIA GPU Feature Discovery
# labels (nvidia.com/gpu.product) and maps them to friendly tiers.
#
# Applied labels:
#   gpu.homelab/tier=<datacenter|training|inference|general>
#   gpu.homelab/product=<sanitized product name>
#   gpu.homelab/vram-gb=<per-GPU VRAM, from nvidia.com/gpu.memory>
#   gpu.homelab/compute-cap=<CUDA compute capability>
#   gpu.homelab/managed=true
#
# Edit the case statement below to taste — this is YOUR fleet, your rules.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_cluster

map_tier() {
  local p="$1"  # lowercase product string
  case "$p" in
    *h100*|*h200*|*a100*|*a800*)       echo "datacenter" ;;
    *5090*|*4090*|*3090*|*rtx-pro*|*rtx-6000*) echo "training" ;;
    *5080*|*5070*|*5060*|*4080*|*4070*|*4060*|*3080*|*3070*|*3060*) echo "inference" ;;
    "")                                 echo "" ;;   # no GPU on this node
    *)                                  echo "general" ;;
  esac
}

title "Auto-labeling GPU nodes by tier"
mapfile -t NODES < <(kc get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}')

for n in "${NODES[@]}"; do
  product="$(kc get node "$n" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.product}' 2>/dev/null || true)"
  count="$(kc get node "$n" -o jsonpath='{.status.allocatable.nvidia\.com/gpu}' 2>/dev/null || true)"
  if [[ -z "$product" ]]; then
    info "$n: no GPU labels yet (CPU-only node, or GPU Operator hasn't finished). Skipping."
    continue
  fi
  tier="$(map_tier "$(echo "$product" | tr '[:upper:]' '[:lower:]')")"
  prod_label="$(sanitize_label "$product")"
  mem_mib="$(kc get node "$n" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.memory}' 2>/dev/null || true)"
  cc_major="$(kc get node "$n" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.compute\.major}' 2>/dev/null || true)"
  cc_minor="$(kc get node "$n" -o jsonpath='{.metadata.labels.nvidia\.com/gpu\.compute\.minor}' 2>/dev/null || true)"
  extra=()
  if [[ -n "$mem_mib" ]]; then
    extra+=("gpu.homelab/vram-gb=$(( (mem_mib + 512) / 1024 ))")
  fi
  if [[ -n "$cc_major" ]]; then
    extra+=("gpu.homelab/compute-cap=${cc_major}.${cc_minor:-0}")
  fi
  vram_gb="-" cc="-"
  if [[ -n "$mem_mib" ]]; then vram_gb="$(( (mem_mib + 512) / 1024 ))"; fi
  if [[ -n "$cc_major" ]]; then cc="${cc_major}.${cc_minor:-0}"; fi
  kc label node "$n" \
    "gpu.homelab/tier=${tier}" \
    "gpu.homelab/product=${prod_label}" \
    "gpu.homelab/managed=true" \
    "${extra[@]}" --overwrite >/dev/null
  ok "$n -> tier=${tier}  product=${prod_label}  gpus=${count:-?}  vram=${vram_gb}GiB  cc=${cc}"
done

hr
echo "Target a tier in any pod/Job/Deployment with:"
echo "    nodeSelector:"
echo "      gpu.homelab/tier: training"
echo
echo "Re-run this any time you add a node. It's safe and idempotent."
