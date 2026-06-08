# Homelab System

Central platform for deploying app repos to the managed k3s cluster and configuring mlapi.us edge routing.

**Contract:** each app repo provides `system.yaml` + `k8s/`. System provides registry entry (`apps/<name>.yaml`), deploy scripts, and nginx configs.

## Layout

```
system/
├── apps/                      # Registry: repo path per app (one line each)
├── schema/system.yaml.example # Copy to app repos as system.yaml
├── docs/adding-an-app.md
├── nginx/
│   ├── upstreams/             # Per-app upstream snippets
│   └── apps/                  # Per-app location blocks
└── scripts/
    ├── lib/app_config.py      # Load + validate registry + system.yaml
    ├── register-app.sh        # Add app to registry from repo path
    ├── validate-app.sh        # Check app repo contract
    ├── deploy-app.sh          # Build, apply, rollout, verify
    ├── import-k3s-image.sh    # Import image to server + worker nodes
    └── install-nginx-app.sh   # Install nginx config (sudo)
```

## Quick start

```bash
# Validate plateforge contract
~/git/system/scripts/validate-app.sh plateforge

# Deploy to managed cluster (build, import, apply, verify)
~/git/system/scripts/deploy-app.sh plateforge deploy

# Install nginx routing on mlapi.us host
sudo ~/git/system/scripts/install-nginx-app.sh plateforge
```

## How it works

1. App repo contains `system.yaml` (deploy contract) and `k8s/base` + `k8s/overlays/{homelab,production}`.
2. System registry `apps/<name>.yaml` points at the repo: `repo: ~/git/myapp`.
3. `deploy-app.sh` merges registry + `system.yaml`, validates layout, builds image, imports to k3s nodes, applies kustomize overlay with server-side apply, waits for rollout, runs verify URLs.

## Register a new app

```bash
cp ~/git/system/schema/system.yaml.example ~/git/myapp/system.yaml
# edit system.yaml, add k8s manifests
~/git/system/scripts/register-app.sh ~/git/myapp
~/git/system/scripts/deploy-app.sh myapp deploy
```

## Conventions

| Item | Location |
|------|----------|
| Deploy contract | `<app-repo>/system.yaml` |
| K8s manifests | `<app-repo>/k8s/` |
| Registry pointer | `~/git/system/apps/<name>.yaml` |
| Homelab overlay | `k8s/overlays/homelab` — local image, no ingress |
| Production overlay | `k8s/overlays/production` — registry image + ingress |
| Edge routing | `~/git/system/nginx/apps/<name>.conf` |

## Environment

| Variable | Purpose |
|----------|---------|
| `K8S_OVERLAY` | `homelab` (default) or `production` |
| `IMAGE_TAG` | Registry tag for production builds |
| `KUBECONFIG` | Target cluster kubeconfig |
| `SKIP_VERIFY=1` | Skip post-deploy health checks |
| `SYSTEM_ROOT` | Path to system repo |
