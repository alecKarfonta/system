# 01 · Overview — how this fits together

You don't need to be a Kubernetes admin to use this, but a mental model helps.

## The layers

```
   your jobs / inference services
   ─────────────────────────────────────────────
   targeting:  node labels (easy)  +  DRA (precise)
   ─────────────────────────────────────────────
   GPU Operator: drivers, runtime, metrics, auto-labels
   ─────────────────────────────────────────────
   k3s: the cluster itself (control plane + workers)
   ─────────────────────────────────────────────
   your machines (varied GPUs, joined over LAN or Tailscale)
```

**k3s** is a small, single-binary Kubernetes. A few **server** nodes form the brain
(the "control plane"); everything else joins as **agent** (worker) nodes. Run **3 servers**
and the cluster survives any one of them rebooting — that's your no-downtime backbone.

**The GPU Operator** is the piece that makes GPUs "just work." When a new machine joins,
it installs the container runtime hooks, (optionally) the driver, a metrics exporter, and
— importantly — **auto-labels** the node with what GPU it has (`nvidia.com/gpu.product`,
memory, count). You don't configure GPUs per-machine; the operator does it.

**Targeting** is how you say "run this on *that* hardware." Two flavors:
- *Node labels* (easy): `make label-gpus` stamps each node with a tier like `training`
  or `inference`. Your workload says `nodeSelector: {gpu.homelab/tier: training}`. Done.
- *DRA* (precise): ask for a GPU by attribute (≥20Gi memory, a specific model). The
  scheduler finds a match anywhere — even within a machine that has mixed cards.

Most of the time, node labels are all you need. Reach for DRA when a single box holds
different GPU types or you want attribute-based matching instead of hand-maintained tags.

## Why these choices

- **k3s over full kubeadm** — join/remove is one command, upgrades are trivial, and it's
  built for exactly this "machines come and go" homelab pattern.
- **GPU Operator over manual device-plugin setup** — heterogeneous fleets are where manual
  setup rots; the operator re-derives everything per node automatically.
- **DRA** — as of Kubernetes 1.34+ this is the native, supported way to allocate GPUs by
  attribute instead of by raw count. It's the right long-term answer to "target specific GPUs."

See `docs/02-install-walkthrough.md` to build it.
