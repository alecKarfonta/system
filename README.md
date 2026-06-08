# Homelab System

Central registry for edge nginx routing and Kubernetes deployment conventions across homelab apps.

Each application keeps its own `k8s/` manifests in its repo. This repo holds shared nginx configs, deploy scripts, and app metadata.

## Layout

```
system/
├── apps/                  # App registry (one YAML per app)
├── docs/adding-an-app.md
├── nginx/
│   ├── 00-upstreams.snippet.conf   # Upstream blocks to merge into edge nginx
│   └── apps/                       # Per-app location blocks for mlapi.us
└── scripts/
    ├── deploy-app.sh               # Build + kustomize apply for any registered app
    ├── import-k3s-image.sh         # Import local Docker image into k3s containerd
    └── install-nginx-app.sh        # Install one app's nginx config (requires sudo)
```

## Quick start

Deploy PlateForge to the homelab k3s cluster:

```bash
~/git/system/scripts/deploy-app.sh plateforge
```

Install or refresh nginx routing (on the mlapi.us host):

```bash
sudo ~/git/system/scripts/install-nginx-app.sh plateforge
```

## Conventions

| Item | Convention |
|------|------------|
| Namespace | App short name (`plateforge`, `speaker`, …) |
| Kustomize | `k8s/base/` + `k8s/overlays/homelab/` and `k8s/overlays/production/` |
| Homelab overlay | Local image import, hostPort, no ingress (host nginx handles TLS) |
| Production overlay | GHCR images, ingress TLS, PVC |
| Edge routing | Upstreams in `00-upstreams.conf`, locations in `conf.d/apps/<app>.conf` |
| Image (homelab) | `docker.io/library/<app>-app:local` imported via k3s ctr |

## Registered apps

See `apps/*.yaml` for repo paths, namespaces, and nginx upstream names.
