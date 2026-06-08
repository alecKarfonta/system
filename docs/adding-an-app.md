# Adding a new app

## 1. Application repo

Create k8s manifests in the app repo:

```
<app-repo>/k8s/
├── base/
│   ├── kustomization.yaml
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── deployment.yaml   # or backend.yaml
│   ├── service.yaml
│   ├── ingress.yaml      # production only (deleted in homelab overlay)
│   └── pvc.yaml          # optional
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

Homelab overlay should:

- Delete ingress resources (host nginx terminates TLS)
- Set `imagePullPolicy: IfNotPresent` and local image name
- Pin `nodeSelector` to the target node if using hostPort
- Expose `hostPort` when nginx on the same node uses `127.0.0.1`

## 2. Register in system repo

Add `apps/<name>.yaml`:

```yaml
name: myapp
repo: ~/git/myapp
namespace: myapp
k8s_overlay: homelab
image_local: docker.io/library/myapp-app:local
compose_service: app
nginx:
  upstream: host196_myapp
  config: nginx/apps/myapp.conf
routes:
  - path: /myapp/
    upstream: host196_myapp
```

## 3. Nginx

1. Add upstream block to `nginx/00-upstreams.snippet.conf`
2. Add location blocks to `nginx/apps/<name>.conf`
3. Include the app conf from `mlapi.us` server block (see stocker `nginx-modular/mlapi.us.conf`)
4. Run `sudo scripts/install-nginx-app.sh <name>`

## 4. Deploy

```bash
~/git/system/scripts/deploy-app.sh <name>
```

For CI/production, set `K8S_OVERLAY=production` and `IMAGE_TAG=<tag>`.
