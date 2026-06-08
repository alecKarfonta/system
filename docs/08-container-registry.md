# 08 · Private container registry

Store large images on your own LAN instead of GHCR/Docker Hub. The registry runs
inside the cluster on **Longhorn** (200Gi PVC by default), serves **HTTPS** with a
self-signed certificate, and is exposed on every node at NodePort **30500**.

## Install

```bash
make registry              # deploy registry + TLS cert + print URL/credentials
make registry-nodes        # configure every k3s node to pull (needs SSH)
make registry-verify       # test HTTPS API + crictl pull on this node
make registry-secret NS=plateforge   # imagePullSecret for a namespace
```

Or enable `INSTALL_REGISTRY=1` in `config/cluster.env` and run `make stack`.

## URLs

| Where | Address |
|---|---|
| Push/pull from your LAN | `https://<SERVER_HOST>:30500` |
| Inside cluster manifests | `<SERVER_HOST>:30500/...` or `registry.registry.svc.cluster.local:5000/...` |

Default user: `homelab`. Password: `config/.registry-password` (auto-generated) or
`REGISTRY_PASSWORD` in `cluster.env`.

k3s nodes trust the self-signed cert via `make registry-nodes`, which installs the CA
into `/usr/local/share/ca-certificates/` and writes `/etc/rancher/k3s/registries.yaml`.

## Push an image

On a build machine, either trust the self-signed cert or allow the registry in Docker:

```json
// /etc/docker/daemon.json — optional if you do not install the cluster CA
{ "insecure-registries": ["192.168.1.78:30500"] }
```

```bash
docker login 192.168.1.78:30500 -u homelab
docker tag myapp:latest 192.168.1.78:30500/plateforge/plateforge:latest
docker push 192.168.1.78:30500/plateforge/plateforge:latest
```

## Use in Kubernetes

```yaml
spec:
  containers:
    - name: plateforge
      image: 192.168.1.78:30500/plateforge/plateforge:latest
```

After `make registry-nodes`, `make registry-verify`, and `make registry-secret NS=plateforge`,
pulls work on every node without GHCR.

## Storage

Images live on the Longhorn PVC `registry-data` in namespace `registry`. Increase
size in `manifests/registry/registry.yaml` if needed.

## Scheduling

The registry pod prefers `homelab/cpu-tier=cheap` nodes (same as light services).
It uses a **Recreate** strategy and a single RWO Longhorn volume — avoid restarting
it during image pushes; a stuck terminating pod blocks volume attach.

## Plateforge: local registry or GHCR

Kubernetes cannot fall back between two image URLs at pull time. Use the helper script
to **prefer the homelab registry when the tag exists and node pulls are verified**,
otherwise keep GHCR:

```bash
make plateforge-images-resolve   # show chosen refs
make plateforge-images-sync      # copy GHCR -> local registry
make registry-nodes              # configure nodes (once)
make registry-verify             # confirm crictl pull works
make plateforge-images           # patch plateforge deployments
```

Set `GHCR_TOKEN` in `config/cluster.env` if the GHCR repo is private (creates
`ghcr-io` pull secret alongside `homelab-registry`).
