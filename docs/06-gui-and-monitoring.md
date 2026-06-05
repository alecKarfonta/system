# 06 · GUI & monitoring — managing without the terminal

You get two complementary web UIs out of the box. Neither needs a complex
third-party platform; both install with the stack.

| Tool         | What it's for                                   | Open with |
|--------------|-------------------------------------------------|-----------|
| **Headlamp** | Manage the cluster: nodes, workloads, scale, edit, logs, shell, RBAC | `make ui` |
| **Grafana**  | Monitor: per-GPU utilization/memory/temp/power, cluster metrics | port-forward (below) |

## Headlamp — the cluster control panel

[Headlamp](https://headlamp.dev) is a CNCF project and the Kubernetes SIG-UI
recommended web dashboard (the old Kubernetes Dashboard was retired). It's a clean,
modern UI that runs **inside your cluster** — no desktop install, no per-machine setup.

What you can do from it without touching a terminal:
- See every node, its GPUs, labels, and live resource usage.
- Browse/scale/restart/delete Deployments, Jobs, Pods across namespaces.
- Edit any resource's YAML in the browser, view logs, exec into a container.
- Watch events as they happen — great for "why is this pod Pending?"

Install + open:

```bash
make dashboard     # once (also runs automatically as part of 'make stack')
make ui            # prints a login token and opens the UI on http://localhost:8080
```

`make ui` runs a `kubectl port-forward` and prints an admin **token** — choose "Token"
on the Headlamp login screen and paste it. The token comes from a cluster-admin
ServiceAccount (`manifests/dashboard/headlamp-admin.yaml`); fine for a private homelab.

### Reaching it without port-forward (optional)

If you'd rather hit it at a stable URL on your LAN/tailnet, expose the service. Quick way:

```bash
kubectl -n kube-system patch svc headlamp -p '{"spec":{"type":"NodePort"}}'
kubectl -n kube-system get svc headlamp     # note the :3xxxx NodePort
# then browse to  http://<server-ip>:<nodeport>
```

For a tidy hostname, put it behind k3s' built-in Traefik ingress instead.

## Grafana — GPU & cluster metrics

The stack installs kube-prometheus-stack. The GPU Operator's DCGM exporter feeds it
per-GPU metrics automatically. Open Grafana:

```bash
kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
# user: admin
# pass: kubectl -n monitoring get secret monitoring-grafana -o jsonpath='{.data.admin-password}' | base64 -d
```

Then import the NVIDIA DCGM dashboard (ID **12239**) for a fleet-wide GPU view —
see `manifests/monitoring/dcgm-dashboard-note.md`.

## What about a single "GPU allocation" UI?

Honest answer: there isn't a great homelab-scale one. The polished GPU-scheduling UIs
(e.g. Run:ai) are enterprise products. The practical setup that covers it:
- **Headlamp** to see what's running where and to deploy/scale/move workloads.
- **Grafana + DCGM** to see how hard each GPU is actually working.
- Your **tier labels / DRA DeviceClasses** to control *where* work lands.

That trio gives you the "robust monitoring + resource allocation" experience without
standing up a heavy platform.

## Other options (if you outgrow the above)

- **k9s** — terminal UI, extremely fast. Not a GUI, but worth `brew/apt install k9s` for quick triage. (You may already use it.)
- **Rancher** (from SUSE, the makers of k3s) — a full management cockpit: multi-cluster,
  RBAC, provisioning, app catalog. It's the most robust option but heavier to run.
  Reach for it only if you end up managing several clusters or want fleet-scale tooling.
- Avoid **Lens/OpenLens** now — the open-source versions have been retired; **FreeLens**
  is the community fork if you specifically want a desktop app.
