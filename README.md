# Homelab GPU Cluster

Turn a pile of mismatched machines into one GPU cluster you can add to, remove from,
and target — without babysitting each box. Built on **k3s** (lightweight Kubernetes),
the **NVIDIA GPU Operator**, and **DRA** for per-GPU targeting. Wrapped in a friendly
`make` interface so you rarely touch raw `kubectl`.

> Designed for people who *know their way around* Kubernetes but don't want to *become a
> Kubernetes administrator* to run a homelab.

## What you get

- **One command to add a machine.** `make add-node` prints a line you paste on the new box. It joins, drivers install themselves, its GPUs show up.
- **No-downtime removal.** `make remove-node NODE=x` drains workloads to other GPUs first, then drops the node.
- **Target specific GPUs.** Tag GPUs by tier (`training`, `inference`, …) and send workloads to exactly the hardware you want — two ways, beginner and power-user.
- **HA control plane** so the cluster keeps running while workers come and go.
- **A web GUI** (Headlamp) for managing the cluster + **Grafana** for per-GPU metrics — no terminal required for day-to-day.
- **Batteries included:** replicated storage (Longhorn), GPU metrics (DCGM → Grafana), works behind CGNAT via Tailscale.

## The 10-minute first run

On the machine you want as your main controller:

```bash
git clone <this-repo> gpu-cluster && cd gpu-cluster
make config                 # creates config/cluster.env
$EDITOR config/cluster.env   # set SERVER_HOST to THIS machine's IP
make preflight              # sanity-check the box
make server                 # install the control plane
make kubeconfig             # so 'kubectl' just works
make stack                  # GPU Operator + DRA + storage + monitoring + web GUI
make label-gpus             # auto-tag GPUs by tier
make status                 # admire your cluster
make ui                     # open the Headlamp web GUI (login token is printed)
```

Add a GPU machine:

```bash
make add-node               # run on the controller; copy the printed line...
# ...then on the NEW machine, after cloning the repo + copying cluster.env:
JOIN_TOKEN='...' make agent
make label-gpus             # back on the controller, re-tag
```

Send a job to your big GPUs:

```bash
kubectl apply -f manifests/examples/02-training-job-nodeselector.yaml
```

## Layout

```
config/      cluster.env  — the ONE file you edit
scripts/     all the logic (install, join, remove, label, status, stack)
manifests/   gpu-operator values, DRA DeviceClasses, ready-to-run examples
docs/        step-by-step guides + glossary + troubleshooting
Makefile     the friendly command menu — run 'make help'
```

## Where to read next

- New to this? → `docs/01-overview.md` then `docs/02-install-walkthrough.md`
- "How do I send work to *this* GPU?" → `docs/03-gpu-targeting.md`
- Adding/removing machines → `docs/04-managing-nodes.md`
- Prefer a UI over the terminal? → `docs/06-gui-and-monitoring.md`
- Something's broken → `docs/05-troubleshooting.md`
- "What does this Kubernetes word mean?" → `docs/glossary.md`

## Requirements

- Machines running Ubuntu/Debian (others may work, untested).
- NVIDIA GPUs. For consumer cards (30xx/40xx/50xx), install the host driver yourself first (`sudo apt install nvidia-driver-XXX`) and keep `GPU_OPERATOR_MANAGES_DRIVER=0`.
- Kubernetes ≥ 1.34 for the DRA per-GPU targeting (k3s `stable` channel is fine). Node-label targeting works on any version.

## Legacy

Pre-k3s shell scripts, docker-compose stacks, and one-off deployments are archived in
[`manual_deployments/`](manual_deployments/README.md). Reference only — do not extend.
