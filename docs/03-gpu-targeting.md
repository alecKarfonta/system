# 03 · Targeting specific GPUs

Two mechanisms. Start with labels; graduate to DRA when you need precision.

## Method A — Node labels (easy, works everywhere)

`make label-gpus` reads each node's GPU model and stamps a tier:

| GPU examples                    | tier        |
|---------------------------------|-------------|
| H100, H200, A100                | datacenter  |
| 5090, 4090, 3090, RTX PRO 6000  | training    |
| 5080/70/60, 4080/70/60, 3080/.. | inference   |
| anything else                   | general     |

The mapping lives in `scripts/label-gpus.sh` — **edit the `case` block to match how you
actually think about your fleet.** Want your 3090 Tis as `training` but one reserved for
streaming inference? Label that node by hand:

```bash
kubectl label node gpu-box-2 gpu.homelab/tier=inference --overwrite
```

Then target it from any workload:

```yaml
spec:
  nodeSelector:
    gpu.homelab/tier: training
```

See `manifests/examples/02-training-job-nodeselector.yaml` and `04-inference-deployment.yaml`.

### Reserving GPUs with taints (keep randoms off)

To stop ordinary pods from landing on a precious node, taint it; only workloads that
explicitly tolerate the taint may schedule there:

```bash
kubectl taint node gpu-box-1 dedicated=training:NoSchedule
```

```yaml
spec:
  tolerations:
    - key: dedicated
      value: training
      effect: NoSchedule
  nodeSelector:
    gpu.homelab/tier: training
```

## Method B — DRA (precise, attribute-based)

DRA lets a workload request a GPU *by what it is*, not *where it is*. The scheduler
matches against every GPU's published attributes across the whole fleet — so it also
works when one machine has mixed cards.

The pieces (installed by `make stack`):
- **DeviceClass** — a named filter, e.g. `training-gpu` = "memory ≥ 20Gi". See `manifests/dra/`.
- **ResourceClaimTemplate** — "give me one GPU from that class."
- Your pod references the template.

```yaml
spec:
  resourceClaims:
    - name: gpu
      resourceClaimTemplateName: one-training-gpu
  containers:
    - name: trainer
      resources:
        claims:
          - name: gpu
```

Full example: `manifests/examples/03-training-job-dra.yaml`.

### Tuning the DeviceClass filters

Attribute names depend on the NVIDIA DRA driver version. To see what's actually published:

```bash
kubectl get resourceslices -o yaml | less
# look under spec.devices[].attributes and .capacity
```

Then edit the CEL `expression` in `manifests/dra/00-deviceclass-training.yaml` to match —
e.g. select by exact product name:

```
device.attributes["gpu.nvidia.com"].productName.matches("RTX 3090")
```

Apply changes with `kubectl apply -f manifests/dra/`.

## Which should I use?

- **Just want jobs on the right class of card?** Node labels. Simpler, fewer moving parts.
- **One box with a 3090 *and* a 5060? Want "any card with ≥24Gi"?** DRA.
- **Mixing both is fine** — label for coarse routing, DRA where you need precision.
