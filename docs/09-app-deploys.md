# App deploys

System fully manages deployments for any app repo that implements the
`system.yaml` contract. **Plateforge** (`~/git/electroplate`) is the reference app.

## Architecture

```
┌─────────────────────┐     ┌──────────────────────┐     ┌─────────────┐
│  app repo           │     │  system repo         │     │  cluster    │
│  system.yaml        │────▶│  apps/plateforge.yaml│────▶│  Deployment │
│  k8s/overlays/      │     │  deploy-app.sh       │     │  Service    │
│  docker-compose.yml │     │  nginx/apps/*.conf   │     │  ConfigMap  │
└─────────────────────┘     └──────────────────────┘     └─────────────┘
                                      │
                                      ▼
                            mlapi.us nginx (edge TLS)
```

| Layer | Owns |
|-------|------|
| App repo | What to run, build config, k8s manifests, verify URLs |
| System repo | Repo registry, deploy scripts, nginx edge configs |
| Cluster | k3s, Longhorn, registry, node labels (`homelab/cpu-tier`, GPU tiers) |

## Quick start

### Deploy an existing app (plateforge)

```bash
make app-validate APP=plateforge
make app-deploy APP=plateforge
make app-verify APP=plateforge
```

### Add a new app

```bash
make app-init NAME=myapp REPO=~/git/myapp PORT=8080
# Edit ~/git/myapp — implement your service, adjust system.yaml
make app-deploy APP=myapp
```

`app-init` creates the app repo layout, registers `apps/myapp.yaml`, and adds
`nginx/apps/myapp.conf` + `nginx/upstreams/myapp.conf` in system.

## Contract

### App repo files

| File | Purpose |
|------|---------|
| `system.yaml` | Build, k8s, storage, verify, nginx metadata |
| `k8s/base/` | Base manifests (namespace, deployment, service, configmap) |
| `k8s/overlays/homelab/` | Local cluster overlay (default) — local image, no ingress |
| `k8s/overlays/homelab-pvc/` | Same as homelab but Longhorn PVC for data |
| `k8s/overlays/production/` | GHCR image + ingress overlay |
| `docker-compose.yml` | Image build source (`service: app`) |

Copy `schema/system.yaml.example` or use `make app-init`.

### Example `system.yaml`

```yaml
name: myapp
namespace: myapp

build:
  compose_file: docker-compose.yml
  service: app
  homelab:
    image: docker.io/library/myapp-app:local
    delivery: import          # import (default) | registry
    registry:
      repo: myapp/myapp
      tag: local
  registry:
    image: ghcr.io/org/myapp
    tag: latest
    push: true

k8s:
  deployment: app
  default_overlay: homelab
  overlays:
    homelab:
      import_nodes: homelab/cpu-tier=cheap
    production: {}

storage:
  sessions:
    type: emptyDir            # emptyDir | pvc
    size: 10Gi

verify:
  - url: https://mlapi.us/myapp/health
    expect_status: 200

nginx:
  name: myapp
  host: auto
  service: app
  service_port: http
  upstreams:
    host196_myapp_api: 8080
```

### System registry

`apps/<name>.yaml` — thin pointer (can override any `system.yaml` field):

```yaml
repo: ~/git/myapp
```

Register manually: `make app-register REPO=~/git/myapp`

## Commands

### Make targets

| Command | Description |
|---------|-------------|
| `make app-init NAME=x REPO=~/git/x` | Scaffold new app repo + register |
| `make app-list` | List apps with cluster status |
| `make app-validate-all` | Validate all contracts |
| `make app-validate APP=x` | Validate one app |
| `make app-deploy APP=x` | Full deploy pipeline |
| `make app-diff APP=x` | Diff manifests vs cluster |
| `make app-status APP=x` | Show namespace resources |
| `make app-delete APP=x` | Remove from cluster |
| `make app-verify APP=x` | Run HTTP verify checks |

### homelab CLI

```bash
homelab app list
homelab app validate-all
homelab app deploy plateforge
homelab app validate myapp
homelab app diff myapp
homelab app status myapp
homelab app delete myapp
homelab app verify myapp
```

### App-repo wrapper (optional)

```bash
#!/usr/bin/env bash
exec ~/git/system/scripts/deploy-app.sh myapp "${1:-deploy}"
```

## Deploy pipeline

`deploy-app.sh` runs these steps in order:

1. **Validate** — contract + k8s layout + nginx configs exist
2. **Ensure namespace** — create namespace so the image-import step (next) can
   schedule its helper Pod
3. **Build** — `docker compose build <service>` in app repo
4. **Deliver image** (homelab overlay):
   - `import` (default): k3s ctr import on server + nodes matching `import_nodes`
   - `registry`: push to homelab private registry (`make registry`)
5. **Apply** — server-side apply of kustomize overlay
6. **Rollout** — wait for deployment ready
7. **Nginx** — sync upstream IPs, install/reload mlapi.us config (so the
   public URL is reachable for verify)
8. **Verify** — HTTP checks from `system.yaml` `verify:` block

### Environment overrides

| Variable | Effect |
|----------|--------|
| `K8S_OVERLAY=production` | Use production overlay + GHCR image |
| `IMAGE_TAG=v1.2.3` | Production registry tag |
| `HOMELAB_DELIVERY=registry` | Push to homelab registry instead of import |
| `SESSIONS_STORAGE=pvc` | Use `homelab-pvc` overlay (Longhorn) |
| `SKIP_VERIFY=1` | Skip HTTP checks |
| `SKIP_NGINX=1` | Skip nginx upstream sync + install |
| `INSTALL_NGINX=0` | Sync upstreams only, skip sudo install |

Production deploy:

```bash
K8S_OVERLAY=production IMAGE_TAG=v1.2.3 make app-deploy APP=myapp
```

## Homelab image delivery

| Mode | When to use | Behavior |
|------|-------------|----------|
| `import` | Default; 1–5 nodes, fast iteration | Build locally → k3s ctr import |
| `registry` | Many nodes; shared image store | Build → push to `make registry` → pull |

Set in `system.yaml` under `build.homelab.delivery` or override with `HOMELAB_DELIVERY=`.

Homelab registry setup: [`08-container-registry.md`](08-container-registry.md)

## Session storage

| `storage.sessions.type` | Overlay used | Data survives pod restart? |
|-------------------------|--------------|----------------------------|
| `emptyDir` (default) | `homelab` | No |
| `pvc` | `homelab-pvc` | Yes (Longhorn) |

```bash
# One-off PVC deploy
SESSIONS_STORAGE=pvc make app-deploy APP=plateforge

# Permanent default in system.yaml
storage:
  sessions:
    type: pvc
    size: 10Gi
```

## Overlay naming

Standard overlays: **`homelab`** and **`production`**.

Do not use `cluster` — rename legacy overlays to `homelab`.

Homelab overlay conventions:

- Delete in-cluster ingress (mlapi.us nginx terminates TLS)
- Rewrite image to local tag via kustomize `images:`
- `imagePullPolicy: IfNotPresent`
- Schedule via `import_nodes` label (e.g. `homelab/cpu-tier=cheap`)

## Nginx edge (multi-site)

The edge nginx is fully managed from this repo. The source of truth is:

```
nginx/
├── <site>.conf                  # one site server block per domain (mlapi.us.conf, stockastic.us.conf, …)
├── snippets/*.conf              # shared location snippets (proxy, ssl, security, …)
├── apps/<site>/<app>.conf       # per-app location blocks, grouped by site
└── upstreams/<app>.conf         # per-app upstream server definitions
```

Each site uses `include /etc/nginx/conf.d/apps/<site>/*.conf;` so any newly
installed app conf is picked up automatically — **no per-app hand-editing of
any site file**. Apps are grouped per-site so confs belonging to different
domains cannot collide on root-level locations (this is why
`stocker-at-root.conf` lives under `apps/stockastic.us/`, not
`apps/mlapi.us/` — it has its own `location /` catchall).

### Adding an app

1. Pick the site the app belongs to (most go under `mlapi.us`).
2. Drop its location conf into `nginx/apps/<site>/<app>.conf`.
3. Drop its upstream def into `nginx/upstreams/<app>.conf`.
4. Run `sudo scripts/install-nginx-app.sh <app>` (site auto-detected).

### What `install-nginx-app.sh` does

Runs as sudo (writes under `/etc/nginx/`, reloads nginx):

```
sudo scripts/install-nginx-app.sh <app> [site]  # one app + sync all sites/snippets
sudo scripts/install-nginx-app.sh --all         # sync every site + snippet + every committed app
sudo scripts/install-nginx-app.sh --sites-only  # sync sites + snippets only (no apps)
sudo scripts/install-nginx-app.sh --migrate     # move flat apps/*.conf into apps/<site>/ subdirs
```

For each run it:

1. Symlinks `nginx/<site>.conf` → `/etc/nginx/sites-available/<site>` (and
   `sites-enabled/`) for **every** site in the repo. Pre-existing regular
   files are backed up.
2. Copies every `nginx/snippets/*.conf` → `/etc/nginx/snippets/` (with backup).
3. (App modes only) Copies the app's conf into
   `/etc/nginx/conf.d/apps/<site>/`.
4. (App modes only) Merges the app's upstream blocks into
   `/etc/nginx/conf.d/00-upstreams.conf`.
5. Runs `nginx -t` and `systemctl reload nginx` (skipped for `--migrate`).

Site for an app is auto-detected from `nginx/apps/<site>/<app>.conf` — pass
the site explicitly only if the same app name exists under multiple sites.

### One-time migration from flat layout

If `/etc/nginx/conf.d/apps/` contains flat `<app>.conf` files (pre-restructure
layout), run once:

```
sudo scripts/install-nginx-app.sh --migrate
sudo scripts/install-nginx-app.sh --sites-only   # or --all
```

`--migrate` assigns each flat conf to a site by:
1. Convention: `*-at-root` → `stockastic.us`.
2. Parsing the pre-migration site backups in `sites-available/*.bak.*` to
   recover each site's old explicit include list.
3. Repo lookup (`nginx/apps/<site>/<app>.conf`).
4. Fallback: `mlapi.us`.

It does **not** reload nginx (the site file likely still has the old glob).
Follow with `--sites-only` to swap in the scoped-glob site files and reload.

### Makefile shortcuts

```bash
make nginx-install APP=noggin   # sudo install-nginx-app.sh noggin
make nginx-install-all          # sudo install-nginx-app.sh --all
make nginx-sync                 # sudo install-nginx-app.sh --sites-only
```

### How it plugs into the deploy pipeline

`make app-deploy APP=<app>` runs the nginx step automatically **before** the
verify step, so first deploys pass the edge health check cleanly:

1. Validate → ensure namespace → build → import image → apply manifests → rollout
2. **Install nginx edge** (`install-nginx-app.sh <app>`)
3. Run verify checks (local + public URLs)

The upstream host is resolved by `sync-nginx-upstream.sh`:

- `MLAPI_UPSTREAM_HOST=<ip>` (config/cluster.env) — force a specific origin host
- `MLAPI_USE_LB=1` — use the k3s LoadBalancer ingress IP instead of `127.0.0.1`
- default — `localhost` (k3s ServiceLB listens on the origin box)

### Manual install / re-sync

```bash
# Refresh upstream IPs from cluster state, then install
scripts/sync-nginx-upstream.sh noggin
sudo scripts/install-nginx-app.sh noggin

# Or do everything via the deploy pipeline
make app-deploy APP=noggin
```

### Recovering the edge on a fresh box

```bash
sudo make nginx-install-all   # every site + snippets + every committed app conf
```

### SSL certificate dependency

`nginx/snippets/ssl-params.conf` and `nginx/snippets/ssl-stockastic.us.conf`
reference Let's Encrypt certs at the standard certbot paths. On a fresh box:

```bash
sudo certbot certonly --nginx -d mlapi.us -d www.mlapi.us
sudo certbot certonly --nginx -d stockastic.us -d www.stockastic.us
```

## Required fields

| Field | Purpose |
|-------|---------|
| `name` | App identifier (matches registry name) |
| `namespace` | Kubernetes namespace |
| `build.service` | docker compose service to build |
| `build.homelab.image` | Local image tag for homelab overlay |
| `k8s.deployment` | Deployment name to wait on |
| `k8s.overlays.homelab` | Homelab overlay config |
| `k8s.overlays.production` | Production overlay config |

## Scaffold template

`schema/app-scaffold/` contains the full layout copied by `make app-init`:

```
schema/app-scaffold/
├── system.yaml
├── Dockerfile
├── docker-compose.yml
├── api/main.py              # FastAPI stub with /health
├── k8s/base/
├── k8s/overlays/homelab/
├── k8s/overlays/homelab-pvc/
├── k8s/overlays/production/
├── scripts/deploy-k8s.sh
└── nginx/                   # templates for system nginx/
```

## Plateforge reference

| Item | Value |
|------|-------|
| App repo | `~/git/electroplate` |
| Registry | `apps/plateforge.yaml` |
| Namespace | `plateforge` |
| Deployment | `backend` (unified UI+API container) |
| Image | `electroplating-app:local` |
| Schedule | `homelab/cpu-tier=cheap` |
| Edge | `https://mlapi.us/plateforge/` |

Deploy from electroplate repo:

```bash
./scripts/deploy-k8s.sh deploy
```

## Legacy

`make plateforge-images*` is **deprecated**. Use:

```bash
make app-deploy APP=plateforge
```

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Missing repo contract: system.yaml` | Add `system.yaml` to app repo or run `make app-init` |
| `found k8s/overlays/cluster` | Rename overlay to `homelab` |
| `ImagePullBackOff` on worker | Image not imported — check `import_nodes` label matches a node; re-run deploy |
| `No nodes match homelab/cpu-tier=cheap` | Run `make label-gpus` or fix `import_nodes` in system.yaml |
| Verify fails after deploy | Check mlapi.us nginx upstream; run `sync-nginx-upstream.sh` |
| Nginx install skipped | Run `sudo scripts/install-nginx-app.sh <app>` manually |
