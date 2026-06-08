# Adding a new app

System can deploy any repo that implements the contract below.

## 1. App repo contract (`system.yaml`)

Copy `schema/system.yaml.example` to your repo root as `system.yaml`:

```yaml
name: myapp
namespace: myapp

build:
  compose_file: docker-compose.yml
  service: app
  homelab:
    image: docker.io/library/myapp-app:local
  registry:
    image: ghcr.io/org/myapp
    tag: latest
    push: true

k8s:
  deployment: backend
  default_overlay: homelab
  overlays:
    homelab:
      import_nodes: homelab/cpu-tier=cheap
    production: {}

verify:
  - url: http://127.0.0.1:8080/health
  - url: https://mlapi.us/myapp/
    expect_status: 200

nginx:
  name: myapp
```

### Required fields

| Field | Purpose |
|-------|---------|
| `name` | App identifier (matches registry name) |
| `namespace` | Kubernetes namespace |
| `build.service` | docker compose service to build |
| `build.homelab.image` | Local image tag for homelab overlay |
| `k8s.deployment` | Deployment resource name to wait on |
| `k8s.overlays` | At least `homelab` and/or `production` |

### Optional overlay fields

| Field | Purpose |
|-------|---------|
| `k8s.overlays.<name>.path` | Custom overlay path (default: `k8s/overlays/<name>`) |
| `k8s.overlays.homelab.import_nodes` | Node label filter for image import (`key=value`) |

## 2. Kubernetes manifests

```
<app-repo>/k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── backend.yaml          # deployment + service
│   ├── ingress.yaml
│   └── pvc.yaml              # optional
└── overlays/
    ├── homelab/
    │   ├── kustomization.yaml
    │   ├── delete-ingress.yaml
    │   ├── deployment-patch.yaml
    │   └── service-patch.yaml
    └── production/
        ├── kustomization.yaml
        └── ingress-patch.yaml
```

Homelab overlay conventions:

- Delete ingress (host nginx terminates TLS on mlapi.us)
- Rewrite image to `build.homelab.image` via kustomize `images:`
- Set `imagePullPolicy: IfNotPresent`
- Use node affinity / LoadBalancer service as needed
- Set `import_nodes` in `system.yaml` to match scheduling labels so images exist on worker nodes

## 3. Register with system

```bash
~/git/system/scripts/register-app.sh ~/git/myapp
```

Creates `apps/myapp.yaml`:

```yaml
repo: ~/git/myapp
```

Registry entries can override any field from the repo's `system.yaml` if needed.

## 4. Nginx (mlapi.us edge)

1. Add upstream blocks to `nginx/upstreams/<app>.conf`
2. Add location blocks to `nginx/apps/<app>.conf`
3. Include the app conf from the mlapi.us server block
4. Run `sudo ~/git/system/scripts/install-nginx-app.sh <app>`

## 5. Deploy

```bash
~/git/system/scripts/validate-app.sh myapp
~/git/system/scripts/deploy-app.sh myapp deploy
```

Commands: `deploy`, `validate`, `diff`, `delete`, `status`, `verify`

Production:

```bash
K8S_OVERLAY=production IMAGE_TAG=v1.2.3 ~/git/system/scripts/deploy-app.sh myapp deploy
```

## App-repo wrapper (optional)

Add a thin script in the app repo:

```bash
#!/bin/bash
exec ~/git/system/scripts/deploy-app.sh myapp "${1:-deploy}"
```
