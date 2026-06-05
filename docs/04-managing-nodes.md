# 04 · Day-to-day: adding & removing machines

## Add a machine (no downtime)

1. On a server: `make add-node` (or `make add-node ROLE=server` for HA control plane).
   It prints a `JOIN_TOKEN='...' make agent` line.
2. On the new machine: install the NVIDIA driver if it's a consumer card
   (`nvidia-smi` should work), clone the repo, copy your `config/cluster.env`, run preflight,
   then paste the join line.
3. Back on a server: `make label-gpus && make status`.

The GPU Operator provisions the new node automatically — you don't install drivers through
Kubernetes by hand. Within a minute or two its GPUs appear in `make status`.

## Remove a machine (no downtime)

```bash
make remove-node NODE=gpu-box-3
```

This **cordons** (no new pods), **drains** (evicts running pods so they reschedule onto
other matching GPUs), then **deletes** the node from the cluster. Long-running services with
2+ replicas and a PodDisruptionBudget (see `04-inference-deployment.yaml`) stay up throughout.

Then, on that physical machine, clean up k3s:

```bash
make uninstall      # or: /usr/local/bin/k3s-agent-uninstall.sh
```

## Pulling just ONE GPU for maintenance (Kubernetes 1.34+/1.36)

DRA can mark a single device unavailable without draining the whole node — the box's other
GPUs keep serving, new claims just avoid the marked one. This is driver/version dependent;
check `kubectl get resourceslices` and the NVIDIA DRA driver docs for the current syntax.

## Rebooting a node

A reboot is fine — k3s restarts automatically and the node rejoins. For planned maintenance
that you want graceful, `kubectl cordon <node>` first, then `kubectl uncordon <node>` after.

## Backups worth taking

- `config/cluster.env` (and the whole repo — commit it to git).
- The server node-token: `/var/lib/rancher/k3s/server/node-token`.
- For real data, Longhorn supports recurring snapshots/backups to an S3 target
  (point it at your MinIO). Configure in the Longhorn UI.
