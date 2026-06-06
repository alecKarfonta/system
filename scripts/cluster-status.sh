#!/usr/bin/env bash
# cluster-status.sh - a friendly, at-a-glance view of your fleet.
source "$(dirname "${BASH_SOURCE[0]}")/lib/common.sh"
require_cluster

# Rich view needs python3; fall back to a plain view if it's not installed.
if ! command -v python3 >/dev/null 2>&1; then
  warn "python3 not found — showing a basic view (install python3 for the full summary)."
  kc get nodes -o wide
  echo
  kc get nodes -L gpu.homelab/tier,nvidia.com/gpu.product,nvidia.com/gpu.count
  exit 0
fi

title "Cluster: $(kc config current-context 2>/dev/null || echo '?')"

printf "%s%-18s %-8s %-10s %-22s %-5s %-11s %-10s%s\n" "$C_BLD" \
  "NODE" "READY" "ROLE" "GPU PRODUCT" "GPUs" "TIER" "DRIVER" "$C_RST"

kc get nodes -o json | python3 -c '
import json, sys
d = json.load(sys.stdin)
for n in d["items"]:
    m = n["metadata"]; name = m["name"]; labels = m.get("labels", {})
    ready = "?"
    for c in n.get("status", {}).get("conditions", []):
        if c["type"] == "Ready":
            ready = "Ready" if c["status"] == "True" else "NotReady"
    role = "worker"
    if labels.get("node-role.homelab/control-plane") == "true":
        role = "control"
    if "node-role.kubernetes.io/control-plane" in labels:
        role = "control"
    prod = labels.get("gpu.homelab/product") or labels.get("nvidia.com/gpu.product", "-")
    gpus = n.get("status", {}).get("allocatable", {}).get("nvidia.com/gpu", "0")
    if gpus == "0" and labels.get("gpu.homelab/count"):
        gpus = labels.get("gpu.homelab/count", "0")
    tier = labels.get("gpu.homelab/tier", "-")
    drv = labels.get("gpu.homelab/driver", "")
    if drv == "pending":
        driver = "pending"
    elif int(gpus or 0) > 0:
        driver = "ok"
    elif labels.get("nvidia.com/gpu.present") == "true":
        driver = "pending"
    else:
        driver = "-"
    print(f"{name:<18} {ready:<8} {role:<10} {str(prod)[:22]:<22} {str(gpus):<5} {tier:<11} {driver:<10}")
'

hr
title "GPU capacity summary"
kc get nodes -o json | python3 -c '
import json, sys
d = json.load(sys.stdin); total = 0; per = {}
for n in d["items"]:
    g = int(n.get("status", {}).get("allocatable", {}).get("nvidia.com/gpu", "0") or 0)
    total += g
    t = n["metadata"].get("labels", {}).get("gpu.homelab/tier", "untagged")
    per[t] = per.get(t, 0) + g
print(f"Total allocatable GPUs: {total}")
for k, v in sorted(per.items()):
    print(f"  tier {k:<12} {v} GPU(s)")
'

echo
title "Recent workloads (all namespaces)"
kc get pods -A --field-selector=status.phase!=Succeeded -o wide 2>/dev/null | head -20 || true
