# Glossary — Kubernetes words, in plain English

- **Node** — one machine in the cluster.
- **Control plane / server node** — a node running the cluster's brain (the API, scheduler,
  state store). Run 3 for high availability.
- **Worker / agent node** — a node that just runs workloads (your GPU boxes).
- **Pod** — the smallest unit you run: one or more containers scheduled together.
- **Deployment** — keeps N copies of a pod running (good for long-lived services).
- **Job** — runs a pod to completion once (good for training runs, batch tasks).
- **kubectl** — the command-line tool you talk to the cluster with.
- **kubeconfig** — the credentials file (`~/.kube/config`) that lets kubectl reach your cluster.
- **Helm** — a package manager for Kubernetes; installs bundles ("charts") like the GPU Operator.
- **nodeSelector** — "only schedule me on nodes with this label." How tier targeting works.
- **Label** — a key=value tag on a node or pod (e.g. `gpu.homelab/tier=training`).
- **Taint / Toleration** — a taint repels pods from a node; a matching toleration lets a
  specific pod ignore it. Used to reserve nodes.
- **Cordon** — mark a node "no new pods." **Drain** — evict existing pods off it (gracefully).
- **PodDisruptionBudget (PDB)** — "never let fewer than N of these be running," which keeps
  services up while you drain nodes.
- **GPU Operator** — NVIDIA's bundle that makes GPUs usable in Kubernetes (drivers, runtime,
  metrics, auto-labels) without per-node setup.
- **GPU Feature Discovery (GFD)** — part of the operator; auto-labels nodes with their GPU
  model, memory, count (`nvidia.com/gpu.*`).
- **DCGM exporter** — ships GPU metrics (util, memory, temp, power) to Prometheus.
- **Device plugin** — the classic way to request GPUs: `nvidia.com/gpu: 1` = "any one GPU."
- **DRA (Dynamic Resource Allocation)** — the modern way: request a GPU *by attribute*
  (model, memory, etc.). Like PersistentVolumeClaims, but for hardware.
- **DeviceClass** — a named filter selecting a kind of device for DRA (e.g. "≥20Gi GPUs").
- **ResourceClaim / ResourceClaimTemplate** — a workload's request for a device from a class.
- **ResourceSlice** — what the DRA driver publishes per node: the catalog of available devices
  and their attributes.
- **Longhorn** — replicated block storage so data survives a node leaving.
- **Tailscale** — a mesh VPN; lets machines join the cluster across networks / behind CGNAT.
