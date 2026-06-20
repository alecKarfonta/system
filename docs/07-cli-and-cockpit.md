# 07 · The `homelab` CLI & Fleet Command GUI

These two are the polished interfaces on top of everything else in this repo.

## The `homelab` CLI — hardware-aware node management

One command, stdlib-python only (runs on a fresh Ubuntu box with nothing installed).
Install it onto your PATH with `make cli`, or run `./cli/homelab` directly.

### Bringing up a brand-new machine — the whole flow

```bash
# on the new machine (repo cloned, cluster.env copied):
homelab doctor --fix        # installs curl etc.; offers the NVIDIA driver if missing
homelab discover            # shows what it found — GPUs, VRAM, compute cap, tier
homelab join worker --token 'K10...'    # token from 'homelab token' on a server
```

**The key feature: hardware self-discovery at join time.** Before joining, the CLI
probes the machine via `nvidia-smi` and registers the node with labels derived from
the actual silicon:

| Label | Example | Meaning |
|---|---|---|
| `gpu.homelab/count` | `4` | number of GPUs |
| `gpu.homelab/vram-gb` | `24` | VRAM per GPU (min across GPUs = safe guarantee) |
| `gpu.homelab/compute-cap` | `8.6` | CUDA compute capability (min) |
| `gpu.homelab/product` | `NVIDIA-GeForce-RTX-3090-Ti` | card model |
| `gpu.homelab/tier` | `training` | auto-mapped tier |
| `homelab/cpu-cores`, `homelab/ram-gb` | `64`, `256` | host resources |
| `homelab/cpu-tier` | `cheap`, `standard`, `performance` | CPU class for light vs heavy CPU work |

So a workload can target hardware *capabilities*, not machine names:

```yaml
nodeSelector:
  gpu.homelab/vram-gb: "24"      # or tier: training, or compute-cap: "8.6"
  homelab/cpu-tier: cheap         # CPU-only / light services off the big boxes
```

For range queries ("VRAM ≥ 20"), use node affinity with `Gt`, or the DRA DeviceClasses —
labels are strings, DRA does real numeric comparison.

### Command reference

```text
homelab doctor [--fix]      check/install deps; offers NVIDIA driver via ubuntu-drivers
homelab discover [--json]   probe hardware; --json for scripting
homelab init                first control-plane (labels itself too)
homelab join worker|server  join + self-label   (--token, optional --server host)
homelab token [role]        print the join command (run on a server)
homelab status              fleet table: GPU model, count, VRAM, compute cap, tier
homelab remove <node>       cordon → drain → delete (no downtime)
homelab label <node> k=v    e.g. 'homelab label box1 tier=inference' (auto-prefixed)
homelab stack | ui | cockpit  install the stack / open the GUIs
homelab app list            registered apps + cluster deploy status
homelab app validate-all    validate every app contract
homelab app deploy <name>   build, apply, verify, sync nginx
homelab app validate|diff|status|delete|verify <name>
```

The make targets and bash scripts still work — the CLI is the nicer front door,
and the only path that auto-labels hardware at join time.

### Managed app deploys

Apps implement a `system.yaml` contract in their repo; system holds `apps/<name>.yaml`
and deploy tooling. See [`09-app-deploys.md`](09-app-deploys.md) for the full spec.

```bash
make app-init NAME=myapp REPO=~/git/myapp     # scaffold repo + register
make app-list                                 # fleet table
make app-deploy APP=plateforge                # full deploy pipeline
homelab app deploy plateforge                 # same via CLI
```

Deploy runs: docker compose build → k3s image import → kustomize apply → rollout wait
→ HTTP verify checks → nginx upstream sync (mlapi.us).

## Fleet Command — the GPU-centric management GUI

`make cockpit` deploys it; it runs *inside* the cluster (tiny: one pod, ~64Mi).
Reach it at **`http://<any-node-ip>:30880`** from anywhere on your LAN/tailnet —
no port-forward, no login dance — or via `make cockpit-ui`.

What it shows, live (8s refresh):
- **Every node** with role (CTRL badge for control planes), readiness, CPU/RAM,
  GPU model, VRAM, compute capability, and tier.
- **Per-GPU allocation meters** — segmented bars showing how many of each node's
  GPUs are claimed, and *which pods* are holding them.
- **Live per-GPU telemetry** — utilization bar (green/amber/red thresholds), core
  temperature, VRAM used/total, and power draw for every GPU, scraped straight
  from the DCGM exporters (no Prometheus required). A FLEET GPU LOAD average sits
  in the header. If the GPU Operator isn't up yet, the UI degrades gracefully to
  allocation-only.
- **Workloads table** — your Deployments with ready/replica counts and GPU usage
  (system namespaces filtered out so it's just *your* stuff).

What you can DO from it:
- **Scale** any Deployment up/down with +/− buttons.
- **Manage workloads** — click MANAGE on any Deployment to set CPU tier scheduling
  (prefer cheap → standard, avoid performance, etc.), CPU/memory requests & limits,
  and rolling strategy (use Recreate for single-replica apps with RWO PVCs).
- **Cordon/uncordon** a node (prep for maintenance without dropping anything).
- **DRAIN a node, one click, with live progress.** The button arms first
  (click → CONFIRM DRAIN, auto-disarms in 4s) so you can't fat-finger it. It then
  cordons the node and issues *PDB-respecting evictions* — pods protected by a
  PodDisruptionBudget are retried while their replicas move, and the card shows an
  amber progress bar (evicted/total) until DRAINED. It never deletes the node
  object; do that with `homelab remove` when the box is really leaving.
- **Reassign GPU and CPU tiers** from dropdowns on each node card — re-routes future scheduling instantly.

Mutations are deliberately scoped: Fleet Command's RBAC can only read nodes/pods/deployments,
patch node schedulability + `gpu.homelab/*` / `homelab/cpu-tier` labels, and scale deployments. It cannot
delete things or read secrets — so exposing it on your LAN is low-risk. (Still keep
it off the public internet.)

Want to preview it before the cluster exists? `make cockpit-demo` runs it locally
on http://localhost:8090 with realistic fake data.

### How it relates to Headlamp & Grafana

- **Fleet Command** = your fleet at a glance + the 90% actions (scale, cordon, tier).
- **Headlamp** = deep generic k8s management (YAML editing, logs, exec, events).
- **Grafana** = GPU utilization/temperature/power over time.

### Customizing it

It's ~370 lines you own: `cockpit/app.py` (stdlib HTTP + k8s API) and
`cockpit/index.html` (vanilla JS). Edit, then re-run `make cockpit` — it repacks
the ConfigMap and restarts the pod. Ideas: a VRAM-sorted fleet heat list, per-pod GPU attribution from DCGM labels, or a utilization history sparkline.
