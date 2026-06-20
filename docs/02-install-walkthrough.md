# 02 · Install walkthrough

## 0. Decide your topology

- **1 machine, just trying it:** make that machine the server. Add workers later.
- **Real cluster:** pick **3 stable machines** as servers (control plane). Everything
  else is a GPU worker. Servers can have GPUs too.
- **Machines across networks / behind CGNAT:** set `TAILSCALE_ENABLED=1` and a
  `TAILSCALE_AUTHKEY` in `cluster.env`, install Tailscale on every machine first, and
  use tailnet IPs for `SERVER_HOST`.

## 1. Configure (once)

On your chosen first server:

```bash
make config
$EDITOR config/cluster.env
```

The only value you *must* set is `SERVER_HOST` — the IP/hostname other machines will use
to reach this server. For consumer GPUs, leave `GPU_OPERATOR_MANAGES_DRIVER=0` and make
sure `nvidia-smi` already works on each GPU box.

## 2. Preflight every machine

```bash
make preflight
```

Run it on each box you'll add. It checks OS, disk, GPU, driver, and clock sync, and tells
you what (if anything) to fix. Nothing here is destructive.

## 3. Install the first server

```bash
make server
make kubeconfig     # writes ~/.kube/config so 'kubectl' works without sudo
kubectl get nodes   # should show one Ready node
```

## 4. (Optional) Add more servers for HA

On the first server: `make add-node ROLE=server` → copy the printed `JOIN_TOKEN=... make join-server`.
On each additional server (repo cloned + cluster.env copied): paste and run it.
**Use an odd number of servers (3).**

## 5. Install the GPU + support stack

```bash
make stack
```

This installs the GPU Operator, the NVIDIA DRA driver, Longhorn storage, and Prometheus/Grafana.
First run takes several minutes (it's pulling driver/toolkit images). When it finishes:

```bash
make label-gpus     # tag nodes by GPU tier
make status         # see GPUs and tiers
make smoke          # run nvidia-smi inside the cluster as a final check
make cockpit-ui     # Fleet Command at http://<node-ip>:30880
```

## 6. Add GPU workers

```bash
make add-node                 # on a server: copy the printed line
# on the new worker:
JOIN_TOKEN='...' make agent
# back on the server:
make label-gpus && make status
```

That's the whole loop. From here, `docs/03-gpu-targeting.md` shows how to aim work at
specific GPUs, and `docs/04-managing-nodes.md` covers day-to-day add/remove.
