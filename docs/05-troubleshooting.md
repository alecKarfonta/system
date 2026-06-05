# 05 · Troubleshooting

## GPUs don't show up (`make status` shows 0 GPUs)

Work through these in order:

1. **Host driver works?** On the GPU box: `nvidia-smi`. If it fails, install the driver
   (`sudo apt install nvidia-driver-XXX`) and reboot. This is the #1 cause on consumer cards.
2. **Operator pods healthy?** `kubectl -n gpu-operator get pods`. Look for the
   `nvidia-container-toolkit` and `device-plugin` pods Running on that node.
3. **k3s containerd wiring.** On k3s the toolkit must point at k3s' containerd. This repo's
   `manifests/gpu-operator/values.yaml` already sets `CONTAINERD_CONFIG` and `CONTAINERD_SOCKET`.
   If you installed the operator without those values, re-run `make stack`.
4. **Check the operator logs:** `kubectl -n gpu-operator logs ds/nvidia-container-toolkit-daemonset`.

## A pod is stuck `Pending`

```bash
kubectl describe pod <name> | sed -n '/Events/,$p'
```

- "0/N nodes available: ... didn't match node selector" → your `nodeSelector` tier doesn't
  exist on any node. Run `make label-gpus`, check `make status`.
- "Insufficient nvidia.com/gpu" → all matching GPUs are busy. Free one or add a node.
- For DRA claims: `kubectl get resourceclaims` — if it's not allocated, your DeviceClass
  filter probably doesn't match any published device (see below).

## DRA: claim never gets allocated

```bash
kubectl get resourceslices -o yaml | less     # what attributes actually exist?
kubectl -n nvidia-dra-driver-gpu logs -l app.kubernetes.io/name=dra-driver-gpu
```

Then fix the CEL `expression` in `manifests/dra/*.yaml` to match the real attribute names
and `kubectl apply -f manifests/dra/`. The DRA driver is newer than the device plugin, so
this is the most likely place to need a tweak. **Node-label targeting always works as a fallback.**

## A node won't join

- Token correct and unexpired? Re-run `make add-node` to reprint it.
- Can the new box reach `SERVER_HOST:6443`? `curl -k https://SERVER_HOST:6443` (a 401 is fine — it means reachable).
- Clock skew breaks TLS: `sudo timedatectl set-ntp true` on both ends.
- Behind CGNAT and not using Tailscale? The worker can't reach the server. Enable Tailscale.

## Drain hangs on `make remove-node`

A pod with no PodDisruptionBudget headroom (e.g. a 1-replica Deployment) can block. Either
scale it up first, or add `--force` understanding it'll be recreated elsewhere. Stateful pods
on local storage need attention — that's why we use Longhorn for anything that matters.

## Reset one node completely

On that machine: `make uninstall`, then re-join with `make agent`. Clean slate.

## Useful one-liners

```bash
kubectl get nodes -o wide
kubectl -n gpu-operator get pods
kubectl describe node <name> | sed -n '/Allocatable/,/System/p'
kubectl get events -A --sort-by=.lastTimestamp | tail -30
```
