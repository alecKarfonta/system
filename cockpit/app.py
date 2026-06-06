#!/usr/bin/env python3
"""Fleet Cockpit backend — dependency-free web app for managing the homelab GPU
cluster. Talks to the Kubernetes API with the pod's ServiceAccount and scrapes
DCGM exporters directly for live per-GPU telemetry (util/temp/VRAM/power).
Set HOMELAB_DEMO=1 to run locally with animated fake data."""
import base64, json, os, random, re, ssl, subprocess, tempfile, threading, time
import urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("PORT", "8090"))
DEMO = os.environ.get("HOMELAB_DEMO") == "1"
API  = "https://kubernetes.default.svc"
SA   = "/var/run/secrets/kubernetes.io/serviceaccount"
JOIN = Path("/var/run/secrets/join")
SSH_SEC = Path("/var/run/secrets/ssh")
HTML = Path(__file__).parent / "index.html"
# ----------------------------------------------------------------- k8s client
def k8s(method, path, body=None, content_type="application/json"):
    token = Path(f"{SA}/token").read_text().strip()
    ctx = ssl.create_default_context(cafile=f"{SA}/ca.crt")
    req = urllib.request.Request(API + path, method=method,
        headers={"Authorization": f"Bearer {token}", "Content-Type": content_type})
    data = json.dumps(body).encode() if body is not None else None
    with urllib.request.urlopen(req, data=data, context=ctx, timeout=15) as r:
        return json.loads(r.read() or b"{}")

# ----------------------------------------------------------------- DCGM telemetry
DCGM = {"DCGM_FI_DEV_GPU_UTIL": "util", "DCGM_FI_DEV_GPU_TEMP": "temp",
        "DCGM_FI_DEV_FB_USED": "vram_used", "DCGM_FI_DEV_FB_FREE": "vram_free",
        "DCGM_FI_DEV_POWER_USAGE": "power",
        "DCGM_FI_DEV_SM_CLOCK": "sm_clock", "DCGM_FI_DEV_MEM_CLOCK": "mem_clock",
        "DCGM_FI_DEV_MEM_COPY_UTIL": "mem_util"}
_LINE = re.compile(r'^(\w+)\{([^}]*)\}\s+([0-9.eE+-]+)')

def scrape_dcgm(ip):
    with urllib.request.urlopen(f"http://{ip}:9400/metrics", timeout=3) as r:
        text = r.read().decode(errors="replace")
    gpus = {}
    for line in text.splitlines():
        m = _LINE.match(line)
        if not m or m.group(1) not in DCGM: continue
        labels = dict(re.findall(r'(\w+)="([^"]*)"', m.group(2)))
        idx = labels.get("gpu", "0")
        slot = gpus.setdefault(idx, {"idx": idx})
        slot[DCGM[m.group(1)]] = float(m.group(3))
        if labels.get("UUID"):
            slot["uuid"] = labels["UUID"]
        if labels.get("modelName"):
            slot["model"] = labels["modelName"]
        for k in ("pod", "namespace", "container"):
            if labels.get(k):
                slot[k] = labels[k]
    return gpus

def telemetry():
    """node -> [per-GPU dicts sorted by index]. Empty on any failure (UI degrades)."""
    if DEMO: return demo_telemetry()
    out = {}
    try:
        sel = urllib.parse.quote("app=nvidia-dcgm-exporter")
        pods = k8s("GET", f"/api/v1/namespaces/gpu-operator/pods?labelSelector={sel}")["items"]
        jobs = [(p["status"].get("podIP"), p["spec"].get("nodeName"))
                for p in pods if p["status"].get("podIP") and p["spec"].get("nodeName")]
        with ThreadPoolExecutor(max_workers=8) as ex:
            futs = {ex.submit(scrape_dcgm, ip): node for ip, node in jobs}
            for f, node in futs.items():
                try: out[node] = f.result()
                except Exception: pass
    except Exception:
        return {}
    return {n: [g[i] for i in sorted(g, key=int)] for n, g in out.items()}

# ----------------------------------------------------------------- demo state
FAKE = {
  "nodes": [
    {"name":"ctrl-1","ready":True,"control":True,"unschedulable":False,"cpu":"8","ram":"32",
     "gpu_product":"-","gpus":0,"vram":"-","cc":"-","tier":"-","gpu_used":0},
    {"name":"trx40-beast","ready":True,"control":False,"unschedulable":False,"cpu":"64","ram":"256",
     "gpu_product":"RTX-3090-Ti","gpus":4,"vram":"24","cc":"8.6","tier":"training","gpu_used":3},
    {"name":"infer-box","ready":True,"control":False,"unschedulable":False,"cpu":"16","ram":"64",
     "gpu_product":"RTX-5060-Ti","gpus":4,"vram":"16","cc":"12.0","tier":"inference","gpu_used":1},
  ],
  "workloads": [
    {"ns":"default","name":"llama-nexus","kind":"Deployment","replicas":2,"ready":2,"gpus":2},
    {"ns":"default","name":"vtuber-tts","kind":"Deployment","replicas":1,"ready":1,"gpus":1},
    {"ns":"ml","name":"yolo-train-e2","kind":"Job","replicas":1,"ready":1,"gpus":1},
  ],
  "pods_by_node": {"trx40-beast":[{"ns":"default","name":"llama-nexus-0","gpus":2},
                                  {"ns":"ml","name":"yolo-train-e2-x","gpus":1}],
                   "infer-box":[{"ns":"default","name":"vtuber-tts-0","gpus":1}]},
  "gpu_procs": {
    "trx40-beast": {"0": [{"kind": "pod", "ns": "default", "name": "llama-nexus-0"}],
                    "1": [{"kind": "pod", "ns": "default", "name": "llama-nexus-0"}],
                    "2": [{"kind": "pod", "ns": "ml", "name": "yolo-train-e2-x"}]},
    "infer-box": {"0": [{"kind": "pod", "ns": "default", "name": "vtuber-tts-0"}]},
  },
}
_DEMO_T = {}
def demo_telemetry():
    spec = {"trx40-beast": (4, 78, 24*1024), "infer-box": (4, 22, 16*1024)}
    for node, (count, base, vram) in spec.items():
        g = _DEMO_T.setdefault(node, [
            {"idx": str(i), "util": float(base + random.randint(-12, 12)),
             "temp": float(52 + random.randint(0, 16)),
             "vram_used": float(vram * random.uniform(.45, .8)), "vram_free": 0.0,
             "power": float(180 + random.randint(0, 160))} for i in range(count)])
        for v in g:
            v["util"] = max(1.0, min(99.0, v["util"] + random.randint(-7, 7)))
            v["temp"] = max(40.0, min(86.0, v["temp"] + random.randint(-2, 2)))
            v["power"] = max(60.0, min(420.0, v["power"] + random.randint(-20, 20)))
            v["vram_free"] = vram - v["vram_used"]
    return _DEMO_T

# ----------------------------------------------------------------- data shaping
def gpu_req(pod):
    return sum(int(c.get("resources", {}).get("limits", {}).get("nvidia.com/gpu", "0") or 0)
               for c in pod["spec"].get("containers", []))

SYS_NS = ("kube-system", "longhorn-system", "monitoring", "gpu-operator",
          "nvidia-dra-driver-gpu", "cockpit")

def _node_vram_gb(lab):
    vram = lab.get("gpu.homelab/vram-gb")
    if vram and vram != "-":
        return vram
    mem = lab.get("nvidia.com/gpu.memory")
    if mem:
        try:
            return str(round(int(mem) / 1024))
        except ValueError:
            pass
    return "-"

def _node_compute_cap(lab):
    cc = lab.get("gpu.homelab/compute-cap")
    if cc and cc != "-":
        return cc
    maj = lab.get("nvidia.com/gpu.compute.major")
    if maj:
        return f"{maj}.{lab.get('nvidia.com/gpu.compute.minor', '0')}"
    return "-"

def _node_gpu_product(lab):
    prod = lab.get("gpu.homelab/product") or lab.get("nvidia.com/gpu.product")
    if prod:
        return prod
    if lab.get("nvidia.com/gpu.present") == "true":
        return "NVIDIA GPU (driver pending)"
    return "-"

def _node_gpu_count(st, lab):
    alloc = int(st.get("allocatable", {}).get("nvidia.com/gpu", "0") or 0)
    if alloc:
        return alloc
    for key in ("gpu.homelab/count", "nvidia.com/gpu.count"):
        v = lab.get(key)
        if v and str(v).isdigit():
            return int(v)
    return 0

def _node_driver_pending(st, lab):
    if int(st.get("allocatable", {}).get("nvidia.com/gpu", "0") or 0) > 0:
        return False
    if lab.get("gpu.homelab/driver") == "pending":
        return True
    labeled = int(lab.get("gpu.homelab/count") or lab.get("nvidia.com/gpu.count") or 0)
    if labeled > 0:
        return True
    return lab.get("nvidia.com/gpu.present") == "true" and not lab.get("nvidia.com/gpu.product")

def _short_gpu_name(name):
    if not name or name == "-":
        return "-"
    s = name.replace("NVIDIA GeForce ", "").replace("NVIDIA ", "").strip()
    return s or name

def _summarize_gpu_models(models):
    """e.g. ['5070 Ti','5060 Ti','5070 Ti','5060 Ti'] -> '2×5070 Ti, 2×5060 Ti'."""
    from collections import Counter
    counts = Counter(_short_gpu_name(m) for m in models if m)
    if not counts:
        return "-"
    parts = []
    for name in sorted(counts, key=lambda n: (-counts[n], n)):
        n = counts[name]
        parts.append(f"{n}×{name}" if n > 1 else name)
    return ", ".join(parts)

def _enrich_node_products(nodes, tel):
    """Replace single-model node labels with a per-GPU inventory when mixed."""
    for n in nodes:
        models = [g.get("model") for g in (tel or {}).get(n["name"], []) if g.get("model")]
        if not models:
            continue
        n["gpu_product"] = _summarize_gpu_models(models)

def _pod_slots(pods):
    """Expand pod GPU counts into one slot per claimed GPU (k8s doesn't expose indices)."""
    slots = []
    for p in pods or []:
        for _ in range(max(1, int(p.get("gpus", 1) or 1))):
            slots.append({"kind": "pod", "ns": p["ns"], "name": p["name"]})
    return slots

def _gpu_processes(idx, tel, slots, demo_procs=None):
    procs = []
    pod = (tel or {}).get("pod", "").strip()
    ns = (tel or {}).get("namespace", "").strip()
    if pod:
        procs.append({"kind": "pod", "ns": ns or "?", "name": pod})
        ctr = (tel or {}).get("container", "").strip()
        if ctr:
            procs[0]["container"] = ctr
    elif demo_procs:
        procs = list(demo_procs)
    elif int(idx) < len(slots):
        procs = [slots[int(idx)]]
    return procs

def flatten_gpus(nodes, tel, pods_by_node, gpu_procs=None):
    """One card dict per physical GPU, sorted hottest-first."""
    cards = []
    for n in nodes:
        count = int(n.get("gpus", 0) or 0)
        if not count:
            continue
        node_tel = {g["idx"]: g for g in (tel or {}).get(n["name"], [])}
        slots = _pod_slots(pods_by_node.get(n["name"], []))
        node_demo = (gpu_procs or {}).get(n["name"], {})
        for i in range(count):
            idx = str(i)
            g = node_tel.get(idx, {"idx": idx})
            procs = _gpu_processes(idx, g, slots, node_demo.get(idx))
            vram_used = float(g.get("vram_used") or 0)
            vram_free = float(g.get("vram_free") or 0)
            vram_total = vram_used + vram_free
            if not vram_total and n.get("vram") not in (None, "-", "?"):
                try:
                    vram_total = float(n["vram"]) * 1024
                except ValueError:
                    pass
            product = _short_gpu_name(g.get("model")) if g.get("model") else n.get("gpu_product", "-")
            vram_gb = str(round(vram_total / 1024)) if vram_total else n.get("vram", "-")
            cards.append({
                "id": f"{n['name']}:{idx}",
                "node": n["name"],
                "node_ready": n["ready"],
                "idx": idx,
                "product": product,
                "tier": n.get("tier", "-"),
                "vram_gb": vram_gb,
                "cc": n.get("cc", "-"),
                "uuid": g.get("uuid", ""),
                "allocated": bool(procs) or i < int(n.get("gpu_used", 0) or 0),
                "util": float(g.get("util") or 0),
                "temp": float(g.get("temp") or 0),
                "power": float(g.get("power") or 0),
                "mem_util": float(g.get("mem_util") or 0),
                "vram_used": vram_used,
                "vram_total": vram_total,
                "sm_clock": float(g.get("sm_clock") or 0),
                "mem_clock": float(g.get("mem_clock") or 0),
                "processes": procs,
                "cordoned": bool(n.get("unschedulable")),
            })
    cards.sort(key=lambda c: (-c["util"], c["node"], int(c["idx"])))
    return cards

def _storage_bytes(raw):
    if not raw or raw == "?":
        return 0
    s = str(raw).strip()
    units = (("Ki", 1024), ("Mi", 1024 ** 2), ("Gi", 1024 ** 3), ("Ti", 1024 ** 4),
             ("K", 1000), ("M", 1000 ** 2), ("G", 1000 ** 3), ("T", 1000 ** 4))
    for suf, mul in units:
        if s.endswith(suf):
            try:
                return int(float(s[:-len(suf)]) * mul)
            except ValueError:
                return 0
    try:
        return int(float(s))
    except ValueError:
        return 0

def _gib_from_bytes(b):
    return round(b / 1024 ** 3, 1) if b else 0.0

def longhorn_by_node():
    """k8s node name -> Longhorn disk totals (bytes aggregated per node)."""
    if DEMO:
        return {
            "trx40-beast": {"total_gib": 1800.0, "avail_gib": 620.0, "used_gib": 1180.0,
                            "scheduled_gib": 940.0, "pct": 66,
                            "disks": [{"name": "default-disk", "path": "/var/lib/longhorn",
                                       "total_gib": 1800.0, "avail_gib": 620.0,
                                       "scheduled_gib": 940.0, "pct": 66}]},
            "infer-box": {"total_gib": 900.0, "avail_gib": 410.0, "used_gib": 490.0,
                          "scheduled_gib": 320.0, "pct": 54,
                          "disks": [{"name": "default-disk", "path": "/var/lib/longhorn",
                                     "total_gib": 900.0, "avail_gib": 410.0,
                                     "scheduled_gib": 320.0, "pct": 54}]},
            "ctrl-1": {"total_gib": 400.0, "avail_gib": 280.0, "used_gib": 120.0,
                       "scheduled_gib": 45.0, "pct": 30,
                       "disks": [{"name": "default-disk", "path": "/var/lib/longhorn",
                                  "total_gib": 400.0, "avail_gib": 280.0,
                                  "scheduled_gib": 45.0, "pct": 30}]},
        }
    out = {}
    items = None
    for ver in ("v1beta2", "v1beta1"):
        try:
            items = k8s("GET",
                        f"/apis/longhorn.io/{ver}/namespaces/longhorn-system/nodes")["items"]
            break
        except Exception:
            items = None
    if not items:
        return out
    for item in items:
        name = item["metadata"]["name"]
        total_b = avail_b = sched_b = 0
        disks = []
        for dname, ds in (item.get("status", {}).get("diskStatus") or {}).items():
            if not ds:
                continue
            mx = int(ds.get("storageMaximum") or 0)
            av = int(ds.get("storageAvailable") or 0)
            sch = int(ds.get("storageScheduled") or 0)
            total_b += mx
            avail_b += av
            sched_b += sch
            disks.append({
                "name": dname,
                "path": ds.get("diskPath", ""),
                "total_gib": _gib_from_bytes(mx),
                "avail_gib": _gib_from_bytes(av),
                "scheduled_gib": _gib_from_bytes(sch),
                "pct": round(100 * (mx - av) / mx) if mx else 0,
            })
        used_b = max(0, total_b - avail_b)
        out[name] = {
            "total_gib": _gib_from_bytes(total_b),
            "avail_gib": _gib_from_bytes(avail_b),
            "used_gib": _gib_from_bytes(used_b),
            "scheduled_gib": _gib_from_bytes(sched_b),
            "pct": round(100 * used_b / total_b) if total_b else 0,
            "disks": disks,
        }
    return out

def _node_storage(name, st, lh_map):
    cap = st.get("capacity", {})
    conditions = st.get("conditions", [])
    disk_pressure = any(c.get("type") == "DiskPressure" and c.get("status") == "True"
                        for c in conditions)
    ephemeral_gib = _gib_from_bytes(_storage_bytes(cap.get("ephemeral-storage", "0")))
    lh = lh_map.get(name)
    return {"longhorn": lh, "ephemeral_gib": ephemeral_gib, "disk_pressure": disk_pressure}

def _cpu_cores(raw):
    if not raw or raw == "?":
        return 0
    s = str(raw)
    if s.endswith("m"):
        return round(int(s[:-1] or 0) / 1000)
    try:
        return int(float(s))
    except ValueError:
        return 0

def cluster_summary(nodes, gpus, workloads, drains, telemetry):
    """Fleet-wide totals, usage, and health for the cluster overview panel."""
    nodes = nodes or []
    gpus = gpus or []
    workloads = workloads or []
    drains = drains or {}
    issues = []

    ready = sum(1 for n in nodes if n.get("ready"))
    cordoned = sum(1 for n in nodes if n.get("unschedulable"))
    draining = sum(1 for d in drains.values()
                    if d.get("phase") in ("starting", "evicting"))
    workers = sum(1 for n in nodes if not n.get("control"))
    control = sum(1 for n in nodes if n.get("control"))

    for n in nodes:
        if not n.get("ready"):
            issues.append({"level": "error", "msg": f"{n['name']} not ready"})
        elif n.get("unschedulable") and drains.get(n["name"], {}).get("phase") not in ("starting", "evicting"):
            issues.append({"level": "warn", "msg": f"{n['name']} cordoned"})

    for node, d in drains.items():
        phase = d.get("phase")
        if phase in ("starting", "evicting"):
            issues.append({"level": "warn",
                            "msg": f"{node} draining ({d.get('evicted', 0)}/{d.get('total') or '…'})"})
        elif phase == "error":
            issues.append({"level": "error", "msg": f"{node} drain failed: {d.get('msg', '')}"})
        elif phase == "timeout":
            issues.append({"level": "error", "msg": f"{node} drain timed out: {d.get('msg', '')}"})

    gpu_total = len(gpus) or sum(int(n.get("gpus", 0) or 0) for n in nodes)
    gpu_alloc = sum(1 for g in gpus if g.get("allocated")) if gpus else \
                sum(int(n.get("gpu_used", 0) or 0) for n in nodes)
    gpu_free = max(0, gpu_total - gpu_alloc)

    utils = [float(g.get("util") or 0) for g in gpus]
    hot = sum(1 for u in utils if u >= 90)
    if hot:
        issues.append({"level": "warn", "msg": f"{hot} GPU(s) above 90% utilization"})

    vram_used_mib = sum(float(g.get("vram_used") or 0) for g in gpus)
    vram_total_mib = sum(float(g.get("vram_total") or 0) for g in gpus)
    if not vram_total_mib:
        for g in gpus:
            try:
                vram_total_mib += float(g.get("vram_gb", 0) or 0) * 1024
            except (TypeError, ValueError):
                pass
    power_w = sum(float(g.get("power") or 0) for g in gpus)

    cpu_cores = sum(_cpu_cores(n.get("cpu")) for n in nodes)
    ram_gib = sum(int(n.get("ram") or 0) for n in nodes if str(n.get("ram", "")).isdigit())

    wl_gpu = sum(int(w.get("gpus", 0) or 0) * int(w.get("replicas", 0) or 0) for w in workloads)
    wl_not_ready = [w for w in workloads if int(w.get("ready", 0) or 0) < int(w.get("replicas", 0) or 0)]
    for w in wl_not_ready:
        issues.append({"level": "warn",
                        "msg": f"{w['ns']}/{w['name']} {w.get('ready', 0)}/{w.get('replicas', 0)} ready"})

    tel_ok = bool(telemetry) and any(telemetry.values())
    gpu_nodes = sum(1 for n in nodes if int(n.get("gpus", 0) or 0) > 0)
    if gpu_nodes and not tel_ok:
        issues.append({"level": "warn", "msg": "GPU telemetry unavailable (DCGM exporter down?)"})

    health = "healthy"
    if any(i["level"] == "error" for i in issues):
        health = "critical"
    elif issues:
        health = "degraded"

    tiers = {}
    for g in gpus:
        t = g.get("tier") or "-"
        if t != "-":
            tiers[t] = tiers.get(t, 0) + 1

    gpu_util = round(sum(utils) / len(utils)) if utils else 0
    vram_pct = round(100 * vram_used_mib / vram_total_mib) if vram_total_mib else 0
    alloc_pct = round(100 * gpu_alloc / gpu_total) if gpu_total else 0

    st_total = st_used = 0.0
    st_nodes = 0
    for n in nodes:
        lh = (n.get("storage") or {}).get("longhorn")
        if not lh or not lh.get("total_gib"):
            continue
        st_nodes += 1
        st_total += float(lh["total_gib"])
        st_used += float(lh.get("used_gib") or 0)
    storage_pct = round(100 * st_used / st_total) if st_total else 0
    for n in nodes:
        if (n.get("storage") or {}).get("disk_pressure"):
            issues.append({"level": "warn", "msg": f"{n['name']} disk pressure"})
    if st_total and storage_pct >= 90:
        issues.append({"level": "warn", "msg": f"Longhorn storage {storage_pct}% used fleet-wide"})

    return {
        "health": health,
        "issues": issues[:8],
        "telemetry": tel_ok,
        "resources": {
            "nodes": {"total": len(nodes), "ready": ready, "workers": workers,
                      "control": control, "cordoned": cordoned, "draining": draining},
            "cpu_cores": cpu_cores,
            "ram_gib": ram_gib,
            "gpus": {"total": gpu_total, "allocated": gpu_alloc, "free": gpu_free},
            "vram_gib": {"total": round(vram_total_mib / 1024, 1),
                         "used": round(vram_used_mib / 1024, 1)},
            "power_w": round(power_w),
            "storage_gib": {"total": round(st_total, 1), "used": round(st_used, 1),
                            "nodes": st_nodes},
        },
        "usage": {
            "gpu_util_pct": gpu_util,
            "gpu_alloc_pct": alloc_pct,
            "vram_pct": vram_pct,
            "storage_pct": storage_pct,
            "workloads": len(workloads),
            "workload_gpus": wl_gpu,
            "gpu_max_pct": round(max(utils)) if utils else 0,
        },
        "tiers": tiers,
    }

def overview():
    if DEMO:
        tel = demo_telemetry()
        lh = longhorn_by_node()
        for n in FAKE["nodes"]:
            n["storage"] = _node_storage(n["name"], {"capacity": {"ephemeral-storage": "500Gi"}},
                                         lh)
        gpus = flatten_gpus(FAKE["nodes"], tel, FAKE["pods_by_node"], FAKE.get("gpu_procs"))
        drains = drain_snapshot()
        return {**FAKE, "telemetry": tel, "gpus": gpus, "drains": drains,
                "cluster": cluster_summary(FAKE["nodes"], gpus, FAKE["workloads"], drains, tel),
                "demo": True}
    nodes_raw = k8s("GET", "/api/v1/nodes")["items"]
    pods_raw  = k8s("GET", "/api/v1/pods?fieldSelector=status.phase=Running")["items"]
    deps_raw  = k8s("GET", "/apis/apps/v1/deployments")["items"]
    used, pods_by_node = {}, {}
    for p in pods_raw:
        node, g = p["spec"].get("nodeName", ""), gpu_req(p)
        if g and node:
            used[node] = used.get(node, 0) + g
            pods_by_node.setdefault(node, []).append(
                {"ns": p["metadata"]["namespace"], "name": p["metadata"]["name"], "gpus": g})
    lh_map = longhorn_by_node()
    nodes = []
    for n in nodes_raw:
        lab, st = n["metadata"].get("labels", {}), n["status"]
        name = n["metadata"]["name"]
        driver_pending = _node_driver_pending(st, lab)
        gpus = _node_gpu_count(st, lab)
        nodes.append({
            "name": name,
            "internal_ip": _node_internal_ip(st),
            "ready": any(c["type"] == "Ready" and c["status"] == "True"
                         for c in st.get("conditions", [])),
            "control": lab.get("node-role.homelab/control-plane") == "true"
                       or "node-role.kubernetes.io/control-plane" in lab,
            "unschedulable": bool(n["spec"].get("unschedulable", False)),
            "cpu": st.get("allocatable", {}).get("cpu", "?"),
            "ram": str(round(int(str(st.get("allocatable", {}).get("memory", "0Ki"))[:-2] or 0) / 1048576)),
            "gpu_product": _node_gpu_product(lab),
            "gpus": gpus,
            "vram": _node_vram_gb(lab),
            "cc": _node_compute_cap(lab),
            "tier": lab.get("gpu.homelab/tier", "-"),
            "gpu_used": used.get(name, 0),
            "driver_pending": driver_pending,
            "storage": _node_storage(name, st, lh_map)})
    wl = [{"ns": d["metadata"]["namespace"], "name": d["metadata"]["name"], "kind": "Deployment",
           "replicas": d["spec"].get("replicas", 0),
           "ready": d["status"].get("readyReplicas", 0) or 0,
           "gpus": sum(int(c.get("resources", {}).get("limits", {}).get("nvidia.com/gpu", "0") or 0)
                       for c in d["spec"]["template"]["spec"].get("containers", []))}
          for d in deps_raw if d["metadata"]["namespace"] not in SYS_NS]
    tel = telemetry()
    _enrich_node_products(nodes, tel)
    gpus = flatten_gpus(nodes, tel, pods_by_node)
    drains = drain_snapshot()
    return {"nodes": nodes, "workloads": wl, "pods_by_node": pods_by_node,
            "telemetry": tel, "gpus": gpus, "drains": drains,
            "cluster": cluster_summary(nodes, gpus, wl, drains, tel),
            "driver": _driver_cfg()}

# ----------------------------------------------------------------- drain manager
DRAINS, _DLOCK = {}, threading.Lock()
def drain_snapshot():
    with _DLOCK:
        return {k: dict(v) for k, v in DRAINS.items()}

def _drain_demo(node):
    st = DRAINS[node]
    st.update(total=max(2, len(FAKE["pods_by_node"].get(node, [])) + 1), phase="evicting")
    for n in FAKE["nodes"]:
        if n["name"] == node: n["unschedulable"] = True
    for i in range(st["total"]):
        time.sleep(1.6); st["evicted"] += 1
    FAKE["pods_by_node"].pop(node, None)
    for n in FAKE["nodes"]:
        if n["name"] == node: n["gpu_used"] = 0
    st["phase"] = "done"

def _drain_real(node):
    st = DRAINS[node]
    try:
        k8s("PATCH", f"/api/v1/nodes/{node}", {"spec": {"unschedulable": True}},
            "application/strategic-merge-patch+json")
        pods = k8s("GET", f"/api/v1/pods?fieldSelector=spec.nodeName={node}")["items"]
        targets = []
        for p in pods:
            if any(o.get("kind") == "DaemonSet" for o in p["metadata"].get("ownerReferences", [])): continue
            if p["metadata"].get("annotations", {}).get("kubernetes.io/config.mirror"): continue
            if p["status"].get("phase") in ("Succeeded", "Failed"): continue
            targets.append((p["metadata"]["namespace"], p["metadata"]["name"]))
        st.update(total=len(targets), phase="evicting")
        remaining, deadline = list(targets), time.time() + 240
        while remaining and time.time() < deadline:
            still = []
            for ns, name in remaining:
                try:
                    k8s("POST", f"/api/v1/namespaces/{ns}/pods/{name}/eviction",
                        {"apiVersion": "policy/v1", "kind": "Eviction",
                         "metadata": {"name": name, "namespace": ns}})
                    st["evicted"] += 1
                except urllib.error.HTTPError as e:
                    if e.code == 429: still.append((ns, name))     # PDB protecting it — retry
                    elif e.code == 404: st["evicted"] += 1          # already gone
                    else: st["failed"] += 1
                except Exception:
                    st["failed"] += 1
            remaining = still
            if remaining:
                st["msg"] = f"{len(remaining)} pod(s) protected by PDBs — waiting for replicas to move"
                time.sleep(4)
        st["phase"] = "done" if not remaining else "timeout"
        if remaining: st["msg"] = f"{len(remaining)} pod(s) still PDB-blocked after 4m"
    except Exception as e:
        st["phase"], st["msg"] = "error", str(e)

def act_drain(b):
    node = b["node"]
    with _DLOCK:
        cur = DRAINS.get(node)
        if cur and cur["phase"] in ("starting", "evicting"):
            return {"ok": True, "already": True}
        DRAINS[node] = {"phase": "starting", "total": 0, "evicted": 0, "failed": 0,
                        "msg": "", "ts": time.time()}
    threading.Thread(target=_drain_demo if DEMO else _drain_real,
                     args=(node,), daemon=True).start()
    return {"ok": True}

# ----------------------------------------------------------------- other actions
def act_scale(b):
    if DEMO:
        for w in FAKE["workloads"]:
            if w["ns"] == b["ns"] and w["name"] == b["name"]:
                w["replicas"] = w["ready"] = max(0, int(b["replicas"]))
        return {"ok": True}
    k8s("PATCH", f"/apis/apps/v1/namespaces/{b['ns']}/deployments/{b['name']}/scale",
        {"spec": {"replicas": max(0, int(b["replicas"]))}}, "application/merge-patch+json")
    return {"ok": True}

def act_cordon(b):
    if DEMO:
        for n in FAKE["nodes"]:
            if n["name"] == b["node"]: n["unschedulable"] = bool(b["on"])
        if not b["on"]:
            with _DLOCK: DRAINS.pop(b["node"], None)
        return {"ok": True}
    k8s("PATCH", f"/api/v1/nodes/{b['node']}", {"spec": {"unschedulable": bool(b["on"])}},
        "application/strategic-merge-patch+json")
    if not b["on"]:
        with _DLOCK: DRAINS.pop(b["node"], None)
    return {"ok": True}

def act_label(b):
    key = b["key"]
    if not (key.startswith("gpu.homelab/") or key.startswith("homelab/")):
        raise ValueError("only gpu.homelab/* and homelab/* labels are editable here")
    if DEMO:
        for n in FAKE["nodes"]:
            if n["name"] == b["node"] and key == "gpu.homelab/tier": n["tier"] = b["value"]
        return {"ok": True}
    k8s("PATCH", f"/api/v1/nodes/{b['node']}",
        {"metadata": {"labels": {key: (b["value"] or None)}}},
        "application/strategic-merge-patch+json")
    return {"ok": True}

# ----------------------------------------------------------------- add node
def _join_cfg():
    def _read(name):
        p = JOIN / name
        return p.read_text().strip() if p.is_file() else ""
    api = {}
    if not DEMO:
        try:
            sec = k8s("GET", "/api/v1/namespaces/cockpit/secrets/cockpit-join")
            api = {k: base64.b64decode(v).decode(errors="replace")
                   for k, v in sec.get("data", {}).items()}
        except Exception:
            pass
    host = os.environ.get("SERVER_HOST") or _read("server_host") or api.get("server_host", "")
    token = os.environ.get("JOIN_TOKEN") or _read("token") or api.get("token", "")
    return {
        "server_host": host,
        "server_port": os.environ.get("SERVER_PORT") or _read("server_port")
                       or api.get("server_port") or "6443",
        "k3s_channel": os.environ.get("K3S_CHANNEL") or _read("k3s_channel")
                         or api.get("k3s_channel") or "stable",
        "token": token,
        "configured": bool(token and host),
    }

def join_info():
    cfg = _join_cfg()
    if DEMO:
        cfg = {**cfg, "configured": True, "token": "K10.demo.token.not.real",
               "server_host": "192.168.1.10", "server_port": "6443", "k3s_channel": "stable"}
    if not cfg["configured"]:
        return {**cfg, "worker_cmd": "", "server_cmd": "", "homelab_cmd": "", "raw_cmd": "",
                "ssh_key_available": _ssh_key_available(),
                "setup_hint": ("Run make cockpit on the controller (or any box with kubectl) "
                               "to create the join secret. Or set JOIN_TOKEN in config/cluster.env "
                               "and re-run make cockpit.")}
    tok, host, port, ch = cfg["token"], cfg["server_host"], cfg["server_port"], cfg["k3s_channel"]
    worker = f"JOIN_TOKEN='{tok}' make agent"
    server = f"JOIN_TOKEN='{tok}' make join-server"
    homelab = (f"homelab doctor --fix && homelab join worker --token '{tok}' "
               f"--server {host}")
    raw = (f"curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL='{ch}' "
           f"K3S_URL='https://{host}:{port}' K3S_TOKEN='{tok}' "
           f"sh -s - agent --node-label node-role.homelab/gpu-worker=true")
    return {**cfg, "worker_cmd": worker, "server_cmd": server,
            "homelab_cmd": homelab, "raw_cmd": raw,
            "ssh_key_available": _ssh_key_available(),
            "prereq": "On the new machine: clone this repo, copy config/cluster.env, then run:"}

ADD_JOBS, _AJLOCK = {}, threading.Lock()
def add_jobs_snapshot():
    with _AJLOCK:
        return {k: dict(v) for k, v in ADD_JOBS.items()}

def _node_names():
    if DEMO:
        return {n["name"] for n in FAKE["nodes"]}
    try:
        return {n["metadata"]["name"] for n in k8s("GET", "/api/v1/nodes")["items"]}
    except Exception:
        return set()

def _node_ready(name):
    if DEMO:
        return any(n["name"] == name and n["ready"] for n in FAKE["nodes"])
    try:
        for n in k8s("GET", "/api/v1/nodes")["items"]:
            if n["metadata"]["name"] != name:
                continue
            return any(c["type"] == "Ready" and c["status"] == "True"
                       for c in n["status"].get("conditions", []))
    except Exception:
        pass
    return False

def _wait_for_node(job_id, expected, known, timeout=600):
    st = ADD_JOBS[job_id]
    deadline = time.time() + timeout
    while time.time() < deadline:
        names = _node_names()
        new = names - known
        target = expected if expected in names and expected not in known else None
        if not target and new:
            target = sorted(new)[0]
        if target and _node_ready(target):
            st.update(phase="done", node=target, msg=f"{target} joined and Ready")
            return
        if target:
            st.update(phase="waiting", node=target, msg=f"waiting for {target} to become Ready…")
        else:
            st.update(phase="waiting", msg="waiting for new node to register…")
        time.sleep(4)
    st.update(phase="timeout", msg="timed out — check the machine and try again")

def _node_internal_ip(st):
    for a in st.get("addresses", []):
        if a.get("type") == "InternalIP":
            return a.get("address")
    return None

def _driver_cfg():
    def _read(name):
        p = JOIN / name
        return p.read_text().strip() if p.is_file() else ""
    api = {}
    if not DEMO:
        try:
            sec = k8s("GET", "/api/v1/namespaces/cockpit/secrets/cockpit-join")
            api = {k: base64.b64decode(v).decode(errors="replace")
                   for k, v in sec.get("data", {}).items()}
        except Exception:
            pass
    op = (_read("gpu_operator_manages_driver") or os.environ.get("GPU_OPERATOR_MANAGES_DRIVER")
          or api.get("gpu_operator_manages_driver") or "0")
    return {
        "operator_manages": op == "1",
        "package": (_read("nvidia_driver_package") or os.environ.get("NVIDIA_DRIVER_PACKAGE")
                    or api.get("nvidia_driver_package") or ""),
        "flavor": (_read("nvidia_driver_flavor") or os.environ.get("NVIDIA_DRIVER_FLAVOR")
                   or api.get("nvidia_driver_flavor") or "open"),
    }

def _driver_install_script():
    p = Path(__file__).parent / "install-nvidia-driver.sh"
    if p.is_file():
        return p.read_text()
    raise RuntimeError("install-nvidia-driver.sh missing from Cockpit bundle")

def _driver_env_shell(cfg):
    pkg = cfg["package"].replace("'", "'\\''")
    return (f"GPU_OPERATOR_MANAGES_DRIVER={'1' if cfg['operator_manages'] else '0'} "
            f"NVIDIA_DRIVER_PACKAGE='{pkg}' NVIDIA_DRIVER_FLAVOR='{cfg['flavor']}'")

def _sudo_run_script(auth, port, user, host, script, env_shell, timeout=900):
    if auth["mode"] == "password":
        pw = _b64_shell(auth["password"])
        scr = _b64_shell(script)
        shell = (
            f"{{ echo '{pw}' | base64 -d; echo; echo '{scr}' | base64 -d; }} | "
            f"sudo -S env {env_shell} bash -s"
        )
        return _ssh_exec(auth, port, user, host, shell, timeout=timeout)
    return _ssh_exec(auth, port, user, host, f"sudo env {env_shell} bash -s",
                     stdin=script, timeout=timeout)

def _tier_for_product(product):
    p = (product or "").lower()
    if any(x in p for x in ("h100", "h200", "a100", "a800")):
        return "datacenter"
    if any(x in p for x in ("5090", "4090", "3090", "rtx-pro", "rtx-6000")):
        return "training"
    if any(x in p for x in ("5080", "5070", "5060", "4080", "4070", "4060", "3080", "3070", "3060")):
        return "inference"
    return "general"

def _sanitize_label(s):
    return re.sub(r"[^A-Za-z0-9._-]", "-", (s or "").replace(" ", "-"))[:63]

def _apply_homelab_gpu_labels(node_name):
    n = k8s("GET", f"/api/v1/nodes/{node_name}")
    lab = n["metadata"].get("labels", {})
    product = lab.get("nvidia.com/gpu.product")
    if not product:
        return False, "waiting for GPU Operator labels (nvidia.com/gpu.product)"
    tier = _tier_for_product(product)
    prod = _sanitize_label(product)
    labels = {
        "gpu.homelab/tier": tier,
        "gpu.homelab/product": prod,
        "gpu.homelab/managed": "true",
        "gpu.homelab/driver": None,
    }
    mem = lab.get("nvidia.com/gpu.memory")
    if mem and str(mem).isdigit():
        labels["gpu.homelab/vram-gb"] = str(round((int(mem) + 512) / 1024))
    maj = lab.get("nvidia.com/gpu.compute.major")
    if maj:
        labels["gpu.homelab/compute-cap"] = f"{maj}.{lab.get('nvidia.com/gpu.compute.minor', '0')}"
    cnt = lab.get("nvidia.com/gpu.count")
    if cnt:
        labels["gpu.homelab/count"] = str(cnt)
    k8s("PATCH", f"/api/v1/nodes/{node_name}",
        {"metadata": {"labels": labels}},
        "application/strategic-merge-patch+json")
    return True, f"labeled {prod} tier={tier}"

def _wait_for_gpu_operator(node_name, timeout=480):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            n = k8s("GET", f"/api/v1/nodes/{node_name}")
            lab = n["metadata"].get("labels", {})
            if lab.get("nvidia.com/gpu.product"):
                alloc = int(n.get("status", {}).get("allocatable", {}).get("nvidia.com/gpu", "0") or 0)
                if alloc > 0:
                    return True
        except Exception:
            pass
        time.sleep(6)
    return False

def _wait_node_ready(node_name, timeout=600):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _node_ready(node_name):
            return True
        time.sleep(5)
    return False

DRIVER_JOBS, _DJLOCK = {}, threading.Lock()

def driver_jobs_snapshot():
    with _DJLOCK:
        return {k: dict(v) for k, v in DRIVER_JOBS.items()}

def _ssh_driver_install(job_id, body):
    cfg = _driver_cfg()
    st = DRIVER_JOBS[job_id]
    node = body.get("node", "").strip()
    host = (body.get("host") or "").strip()
    if not host and node:
        try:
            n = k8s("GET", f"/api/v1/nodes/{node}")
            host = _node_internal_ip(n.get("status", {})) or ""
        except Exception:
            pass
    if not host:
        st.update(phase="error", msg="host or resolvable node required")
        return
    if cfg["operator_manages"]:
        st.update(phase="error",
                  msg="GPU_OPERATOR_MANAGES_DRIVER=1 — operator installs drivers cluster-wide")
        return
    user = body.get("user", "root").strip() or "root"
    port = int(body.get("port") or 22)
    do_reboot = body.get("reboot", True)
    auth = None
    try:
        auth = _resolve_ssh_auth(body)
        st.update(phase="connecting", msg=f"SSH {user}@{host}…")
        proc = _ssh_exec(auth, port, user, host, "true", timeout=20)
        if proc.returncode != 0:
            st.update(phase="error", msg=_ssh_err(proc, auth))
            return
        proc = _ssh_exec(auth, port, user, host, _sudo_test_shell(auth, user), timeout=30)
        if proc.returncode != 0:
            st.update(phase="error", msg=_ssh_err(proc, auth))
            return
        script = _driver_install_script()
        env_shell = _driver_env_shell(cfg)
        st.update(phase="installing", msg="installing NVIDIA driver packages…")
        proc = _sudo_run_script(auth, port, user, host, script, env_shell, timeout=900)
        out = _proc_tail(proc, "")
        need_reboot = proc.returncode == 2 or "REBOOT_REQUIRED" in (proc.stdout or "")
        if proc.returncode not in (0, 2):
            st.update(phase="error", msg=_proc_tail(proc, "driver install failed"))
            return
        if proc.returncode == 0 and "DRIVER_OK" in (proc.stdout or ""):
            st.update(phase="labeling", msg="driver OK — applying GPU labels…")
        elif need_reboot and do_reboot:
            st.update(phase="rebooting", msg="rebooting node…")
            if auth["mode"] == "password":
                pw = _b64_shell(auth["password"])
                _ssh_exec(auth, port, user, host,
                          f"echo '{pw}' | base64 -d | sudo -S reboot", timeout=15)
            else:
                _ssh_exec(auth, port, user, host, "sudo reboot", timeout=15)
            time.sleep(20)
            st.update(phase="waiting", msg=f"waiting for {node or host} to come back…")
            if node and not _wait_node_ready(node, 600):
                st.update(phase="error", msg="node did not become Ready after reboot")
                return
            st.update(phase="labeling", msg="waiting for GPU Operator…")
        elif need_reboot:
            st.update(phase="error", msg="driver installed — reboot the node manually, then run label-gpus")
            return
        else:
            st.update(phase="labeling", msg="waiting for GPU Operator…")
        if node:
            if not _wait_for_gpu_operator(node, 480):
                st.update(phase="error",
                          msg="driver up but GPU Operator has not registered GPUs yet — try again shortly")
                return
            ok, msg = _apply_homelab_gpu_labels(node)
            if not ok:
                st.update(phase="error", msg=msg)
                return
            st.update(phase="done", msg=f"driver ready — {msg}")
        else:
            st.update(phase="done", msg=out or "driver installed")
    except subprocess.TimeoutExpired:
        st.update(phase="error", msg="SSH or driver install timed out")
    except Exception as e:
        st.update(phase="error", msg=str(e))
    finally:
        if auth and auth.get("cleanup") and auth.get("keypath"):
            try:
                os.unlink(auth["keypath"])
            except OSError:
                pass

def act_driver_install(b):
    node = (b.get("node") or "").strip()
    host = (b.get("host") or "").strip()
    if not node and not host:
        raise ValueError("node or host required")
    cfg = _driver_cfg()
    if cfg["operator_manages"]:
        raise ValueError("GPU_OPERATOR_MANAGES_DRIVER=1 — change cluster.env and re-run make stack")
    job_id = f"driver-{node or host}-{int(time.time())}"
    with _DJLOCK:
        DRIVER_JOBS[job_id] = {"id": job_id, "node": node, "host": host,
                               "phase": "starting", "msg": "", "ts": time.time()}
    if DEMO:
        def demo():
            st = DRIVER_JOBS[job_id]
            for phase, msg, delay in [
                ("connecting", "SSH demo…", 1),
                ("installing", "installing driver…", 2),
                ("rebooting", "rebooting…", 1.5),
                ("labeling", "applying labels…", 1),
            ]:
                st.update(phase=phase, msg=msg)
                time.sleep(delay)
            st.update(phase="done", msg="driver ready (demo)")
        threading.Thread(target=demo, daemon=True).start()
    else:
        threading.Thread(target=_ssh_driver_install, args=(job_id, b), daemon=True).start()
    return {"ok": True, "id": job_id}

def _sanitize_node_name(name):
    name = (name or "").strip().lower()
    name = re.sub(r"[^a-z0-9-]", "-", name)
    name = re.sub(r"-+", "-", name).strip("-")
    return (name[:63] or "node")

def _node_name_from_host(host):
    """Fallback when SSH hostname lookup fails."""
    host = (host or "").strip()
    if re.match(r"^\d+\.\d+\.\d+\.\d+$", host):
        return f"node-{host.rsplit('.', 1)[-1]}"
    return _sanitize_node_name(host.split(".")[0] or "node")

def _resolve_node_name(auth, port, user, host, known):
    """Use the machine's system hostname for k3s --node-name (e.g. threadripper)."""
    proc = _ssh_exec(auth, port, user, host,
                     "hostname -s 2>/dev/null || hostname 2>/dev/null | cut -d. -f1",
                     timeout=15)
    raw = (proc.stdout or "").strip().split(".")[0] if proc.returncode == 0 else ""
    base = _sanitize_node_name(raw) if raw else _node_name_from_host(host)
    if base not in known:
        return base
    if re.match(r"^\d+\.\d+\.\d+\.\d+$", host):
        suffixed = _sanitize_node_name(f"{base}-{host.rsplit('.', 1)[-1]}")
        if suffixed not in known:
            return suffixed
    return _node_name_from_host(host)

def _remote_bootstrap_sh(cfg, role, node_name=""):
    tok, host, port, ch = cfg["token"], cfg["server_host"], cfg["server_port"], cfg["k3s_channel"]
    label_role = "control-plane" if role == "server" else "gpu-worker"
    return f"""#!/bin/bash
set -euo pipefail
tier_for() {{
  local p="${{1,,}}"
  [[ "$p" == *h100* || "$p" == *a100* ]] && echo datacenter && return
  [[ "$p" == *5090* || "$p" == *4090* || "$p" == *3090* ]] && echo training && return
  [[ "$p" == *5080* || "$p" == *4080* || "$p" == *3060* ]] && echo inference && return
  echo general
}}
LABELS=(--node-label "node-role.homelab/{label_role}=true")
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  GPU_LINE="$(nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader 2>/dev/null | head -1 || true)"
  if [[ -n "$GPU_LINE" && "$GPU_LINE" == *,* ]]; then
    IFS=',' read -r NAME MEM CC <<< "$GPU_LINE"
    NAME="${{NAME// /}}"
    MEM_GB=$(( (${{MEM//[^0-9]/}} + 512) / 1024 ))
    TIER="$(tier_for "$NAME")"
    PROD="$(echo "$NAME" | tr ' ' '-' | tr -cd 'A-Za-z0-9._-' | cut -c1-63)"
    LABELS+=(--node-label "gpu.homelab/product=$PROD" --node-label "gpu.homelab/tier=$TIER"
              --node-label "gpu.homelab/vram-gb=$MEM_GB" --node-label "gpu.homelab/managed=true")
    [[ "$CC" =~ ^[0-9]+\\.[0-9]+$ ]] && LABELS+=(--node-label "gpu.homelab/compute-cap=$CC")
    COUNT="$(nvidia-smi --query-gpu=name --format=csv,noheader 2>/dev/null | wc -l | tr -d ' ' || true)"
    LABELS+=(--node-label "gpu.homelab/count=$COUNT")
  fi
elif command -v lspci >/dev/null 2>&1 && lspci -Dnnd 10de: 2>/dev/null | grep -q '0300'; then
  pci_gpu_hint() {{
    case "$1" in
      2f04) echo "NVIDIA-GeForce-RTX-5070:12" ;;
      2684|2704) echo "NVIDIA-GeForce-RTX-4090:24" ;;
      2204|2208) echo "NVIDIA-GeForce-RTX-3090:24" ;;
      2484|2489) echo "NVIDIA-GeForce-RTX-5080:16" ;;
      *) echo "NVIDIA-PCI-$1:0" ;;
    esac
  }}
  COUNT="$(lspci -Dnnd 10de: 2>/dev/null | grep -c '0300' || echo 1)"
  PCI_ID="$(lspci -Dnnd 10de: 2>/dev/null | grep '0300' | head -1 | grep -oE '10de:[0-9a-f]{{4}}' | cut -d: -f2 || true)"
  IFS=: read -r PROD VRAM <<< "$(pci_gpu_hint "${{PCI_ID:-unknown}}")"
  TIER="$(tier_for "$PROD")"
  LABELS+=(--node-label "gpu.homelab/product=$PROD" --node-label "gpu.homelab/tier=$TIER"
            --node-label "gpu.homelab/count=$COUNT" --node-label "gpu.homelab/managed=true"
            --node-label "gpu.homelab/driver=pending")
  [[ -n "$VRAM" && "$VRAM" != "0" ]] && LABELS+=(--node-label "gpu.homelab/vram-gb=$VRAM")
fi
CORES="$(nproc 2>/dev/null || echo 0)"
RAM_GB="$(awk '/MemTotal/ {{printf "%d", $2/1024/1024}}' /proc/meminfo 2>/dev/null || echo 0)"
LABELS+=(--node-label "homelab/cpu-cores=$CORES" --node-label "homelab/ram-gb=$RAM_GB")
export INSTALL_K3S_CHANNEL='{ch}'
NODE_NAME='{node_name or ""}'
if [[ -z "$NODE_NAME" ]]; then
  NODE_NAME="$(hostname -s 2>/dev/null || hostname 2>/dev/null | cut -d. -f1)"
fi
NODE_NAME="${{NODE_NAME,,}}"
NODE_NAME="$(echo "$NODE_NAME" | tr -cd 'a-z0-9-' | sed 's/^-*//;s/-*$//')"
[[ -z "$NODE_NAME" ]] && NODE_NAME='node'
if [[ "{role}" == "server" ]]; then
  export K3S_TOKEN='{tok}'
  curl -sfL https://get.k3s.io | sh -s - server --server 'https://{host}:{port}' --node-name "$NODE_NAME" "${{LABELS[@]}}"
else
  export K3S_URL='https://{host}:{port}' K3S_TOKEN='{tok}'
  curl -sfL https://get.k3s.io | sh -s - agent --node-name "$NODE_NAME" "${{LABELS[@]}}"
fi
echo JOINED
"""

def _ssh_key_available():
    if DEMO:
        return True
    return any((SSH_SEC / n).is_file() for n in ("id_ed25519", "id_rsa", "key"))

def _normalize_key(key):
    key = (key or "").replace("\r\n", "\n").replace("\r", "\n").strip()
    if key and "BEGIN" in key and not key.endswith("\n"):
        key += "\n"
    return key

def _resolve_ssh_key(body):
    """Return key path. Writes a temp file for pasted keys; caller must unlink."""
    pasted = _normalize_key(body.get("key", ""))
    use_saved = body.get("use_saved_key", not pasted)
    if pasted and not use_saved:
        if "BEGIN" not in pasted or "PRIVATE KEY" not in pasted:
            raise ValueError("paste the full private key (BEGIN…END lines)")
        fd, path = tempfile.mkstemp(prefix="cockpit-ssh-", text=True)
        with os.fdopen(fd, "w") as f:
            f.write(pasted)
        os.chmod(path, 0o600)
        return path
    for name in ("id_ed25519", "id_rsa", "key"):
        p = SSH_SEC / name
        if p.is_file():
            return str(p)
    if pasted:
        fd, path = tempfile.mkstemp(prefix="cockpit-ssh-", text=True)
        with os.fdopen(fd, "w") as f:
            f.write(pasted)
        os.chmod(path, 0o600)
        return path
    raise ValueError("no SSH key — paste a private key or re-run make cockpit to save your cluster key")

def _resolve_ssh_auth(body):
    """Return auth dict: mode password|key, plus password or keypath."""
    password = (body.get("password") or "")
    if password is not None and not isinstance(password, str):
        password = str(password)
    use_password = bool(body.get("use_password")) or bool(password)
    if use_password:
        if not password:
            raise ValueError("SSH password required")
        return {"mode": "password", "password": password, "keypath": None, "cleanup": False}
    keypath = _resolve_ssh_key(body)
    return {"mode": "key", "password": None, "keypath": keypath,
            "cleanup": keypath.startswith(tempfile.gettempdir())}

def _b64_shell(s):
    """Base64-encode bytes for safe embedding in a single-quoted remote shell."""
    return base64.b64encode(s.encode()).decode()

def _sudo_test_shell(auth, user="root"):
    if user == "root":
        return "true"
    if auth["mode"] != "password":
        return "sudo -n true"
    pw = _b64_shell(auth["password"])
    # Avoid printf/sudo -p '' in one sh -c string — dash mangles the quotes.
    return f"echo '{pw}' | base64 -d | sudo -S true"

def _sudo_bootstrap_exec(auth, port, user, host, boot, timeout=480):
    if auth["mode"] == "password":
        pw = _b64_shell(auth["password"])
        script = _b64_shell(boot)
        shell = f"{{ echo '{pw}' | base64 -d; echo; echo '{script}' | base64 -d; }} | sudo -S bash -s"
        return _ssh_exec(auth, port, user, host, shell, timeout=timeout)
    if user == "root":
        return _ssh_exec(auth, port, user, host, "bash -s", stdin=boot, timeout=timeout)
    return _ssh_exec(auth, port, user, host, "sudo bash -s", stdin=boot, timeout=timeout)

def _ssh_exec(auth, port, user, host, shell, stdin=None, timeout=60):
    env = os.environ.copy()
    opts = ["-p", str(port), "-o", "ConnectTimeout=20", "-o", "StrictHostKeyChecking=accept-new"]
    target = f"{user}@{host}"
    # Run through the remote login shell — not sh -c, which breaks sudo -S pipelines.
    if auth["mode"] == "password":
        env["SSHPASS"] = auth["password"]
        cmd = (["sshpass", "-e", "ssh"] + opts +
               ["-o", "BatchMode=no", "-o", "PubkeyAuthentication=no",
                "-o", "PreferredAuthentications=password", target, shell])
    else:
        cmd = (["ssh", "-i", auth["keypath"]] + opts +
               ["-o", "BatchMode=yes", "-o", "IdentitiesOnly=yes",
                "-o", "PubkeyAuthentication=no", target, shell])
    return subprocess.run(cmd, input=stdin, capture_output=True, text=True, timeout=timeout, env=env)

def _ssh_err(proc, auth):
    err = (proc.stderr or proc.stdout or "ssh failed").strip()
    if "Permission denied" in err:
        if auth["mode"] == "password":
            err += " — check username/password and that PasswordAuthentication is enabled on the target."
        else:
            err += (" — use password auth, or run ssh-copy-id USER@HOST then make cockpit.")
    elif "usage: sudo" in err or "a password is required" in err.lower():
        err += " — sudo failed (wrong password or user lacks sudo)."
    return err[-500:]

def _proc_tail(proc, fallback="command failed"):
    lines = []
    for stream in (proc.stdout, proc.stderr):
        if not stream:
            continue
        for line in stream.splitlines():
            s = line.strip()
            if not s or s.lower().startswith("[sudo] password"):
                continue
            lines.append(s)
    return ("\n".join(lines).strip() or fallback)[-500:]

def act_ssh_test(b):
    host = (b.get("host") or "").strip()
    if not host:
        raise ValueError("host required")
    user = b.get("user", "root").strip() or "root"
    port = int(b.get("port") or 22)
    auth = _resolve_ssh_auth(b)
    try:
        proc = _ssh_exec(auth, port, user, host, "true", timeout=20)
        if proc.returncode != 0:
            raise ValueError(_ssh_err(proc, auth))
        proc = _ssh_exec(auth, port, user, host, _sudo_test_shell(auth, user), timeout=30)
        if proc.returncode != 0:
            err = _ssh_err(proc, auth)
            if auth["mode"] == "password" and "Permission denied" not in err:
                err += " — SSH login worked; check sudo password / group membership."
            raise ValueError(err)
        via = "password" if auth["mode"] == "password" else "key"
        return {"ok": True, "msg": f"SSH OK ({via}) — {user}@{host} can sudo"}
    finally:
        if auth.get("cleanup") and auth.get("keypath"):
            try: os.unlink(auth["keypath"])
            except OSError: pass

def _ssh_join(job_id, body):
    cfg = _join_cfg()
    if not cfg["configured"]:
        ADD_JOBS[job_id].update(phase="error",
            msg="join token missing — run make cockpit (creates join secret) or set JOIN_TOKEN in cluster.env")
        return
    host = body["host"].strip()
    user = body.get("user", "root").strip() or "root"
    port = int(body.get("port") or 22)
    role = body.get("role", "worker")
    known = _node_names()
    st = ADD_JOBS[job_id]
    st.update(phase="connecting", msg=f"SSH {user}@{host}:{port}…")
    auth = None
    try:
        auth = _resolve_ssh_auth(body)
        proc = _ssh_exec(auth, port, user, host, "true", timeout=20)
        if proc.returncode != 0:
            st.update(phase="error", msg=_ssh_err(proc, auth))
            return
        proc = _ssh_exec(auth, port, user, host, _sudo_test_shell(auth, user), timeout=30)
        if proc.returncode != 0:
            err = _ssh_err(proc, auth)
            if auth["mode"] == "password" and "Permission denied" not in err:
                err += " — SSH login worked; check sudo password / group membership."
            st.update(phase="error", msg=err)
            return
        st.update(phase="bootstrap", msg="installing k3s and labeling GPUs…")
        node_name = _resolve_node_name(auth, port, user, host, known)
        boot = _remote_bootstrap_sh(cfg, role, node_name)
        proc = _sudo_bootstrap_exec(auth, port, user, host, boot)
        if proc.returncode != 0:
            hint = ""
            if proc.returncode == 9 and not _proc_tail(proc, ""):
                hint = " — nvidia-smi/driver issue on target (node can still join without GPU labels)"
            st.update(phase="error", msg=_proc_tail(proc, "bootstrap failed") + hint)
            return
        expected = node_name
        st.update(expected=expected, phase="waiting", msg=f"bootstrap done — waiting for {expected}…")
        _wait_for_node(job_id, expected, known)
    except subprocess.TimeoutExpired:
        st.update(phase="error", msg="SSH or k3s install timed out")
    except Exception as e:
        st.update(phase="error", msg=str(e))
    finally:
        if auth and auth.get("cleanup") and auth.get("keypath"):
            try: os.unlink(auth["keypath"])
            except OSError: pass

def _ssh_demo(job_id, body):
    st = ADD_JOBS[job_id]
    host = body.get("host", "new-box")
    for phase, msg, delay in [
        ("connecting", f"SSH {body.get('user','root')}@{host}…", 1.2),
        ("bootstrap", "installing k3s and labeling GPUs…", 2.5),
        ("waiting", "waiting for new-box to register…", 1.5),
    ]:
        st.update(phase=phase, msg=msg); time.sleep(delay)
    FAKE["nodes"].append({"name": "new-box", "ready": True, "control": False,
        "unschedulable": False, "cpu": "32", "ram": "128", "gpu_product": "RTX-4070",
        "gpus": 2, "vram": "12", "cc": "8.9", "tier": "inference", "gpu_used": 0})
    st.update(phase="done", node="new-box", msg="new-box joined and Ready (demo)")

def act_add_ssh(b):
    host = (b.get("host") or "").strip()
    if not host:
        raise ValueError("host required")
    job_id = f"ssh-{host}-{int(time.time())}"
    with _AJLOCK:
        ADD_JOBS[job_id] = {"id": job_id, "method": "ssh", "host": host,
                            "role": b.get("role", "worker"), "phase": "starting",
                            "msg": "", "ts": time.time()}
    fn = _ssh_demo if DEMO else _ssh_join
    threading.Thread(target=fn, args=(job_id, b), daemon=True).start()
    return {"ok": True, "id": job_id}

def act_add_watch(b):
    expected = (b.get("expected") or "").strip()
    job_id = f"watch-{expected or 'any'}-{int(time.time())}"
    known = _node_names()
    with _AJLOCK:
        ADD_JOBS[job_id] = {"id": job_id, "method": "watch", "expected": expected,
                            "role": b.get("role", "worker"), "phase": "waiting",
                            "msg": "watching for node…", "ts": time.time()}
    def run():
        if DEMO:
            time.sleep(3)
            ADD_JOBS[job_id].update(phase="done", node=expected or "new-box",
                                    msg=f"{expected or 'new-box'} detected (demo)")
            return
        _wait_for_node(job_id, expected, known)
    threading.Thread(target=run, daemon=True).start()
    return {"ok": True, "id": job_id}

ACTIONS = {"/api/scale": act_scale, "/api/cordon": act_cordon,
           "/api/label": act_label, "/api/drain": act_drain,
           "/api/add-node/ssh": act_add_ssh, "/api/add-node/watch": act_add_watch,
           "/api/add-node/ssh-test": act_ssh_test, "/api/driver/install": act_driver_install}

# ----------------------------------------------------------------- http
class H(BaseHTTPRequestHandler):
    def log_message(self, *a): pass
    def _send(self, code, body, ctype="application/json"):
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype); self.send_header("Content-Length", len(data))
        self.end_headers(); self.wfile.write(data)
    def do_GET(self):
        path = urllib.parse.urlparse(self.path).path
        if path in ("/", "/index.html"):
            self._send(200, HTML.read_bytes(), "text/html; charset=utf-8")
        elif path == "/healthz":
            self._send(200, {"ok": True})
        elif path == "/api/overview":
            try: self._send(200, overview())
            except Exception as e: self._send(502, {"error": str(e)})
        elif path == "/api/drains":
            self._send(200, drain_snapshot())
        elif path == "/api/join":
            self._send(200, join_info())
        elif path == "/api/add-node/jobs":
            self._send(200, add_jobs_snapshot())
        elif path == "/api/driver/jobs":
            self._send(200, driver_jobs_snapshot())
        elif path == "/api/driver/config":
            self._send(200, _driver_cfg())
        else: self._send(404, {"error": "not found"})
    def do_POST(self):
        fn = ACTIONS.get(urllib.parse.urlparse(self.path).path)
        if not fn: return self._send(404, {"error": "not found"})
        try:
            n = int(self.headers.get("Content-Length", "0"))
            self._send(200, fn(json.loads(self.rfile.read(n) or b"{}")))
        except Exception as e:
            self._send(400, {"error": str(e)})

if __name__ == "__main__":
    print(f"Fleet Cockpit on :{PORT}  [{'DEMO (fake data)' if DEMO else 'live cluster'}]", flush=True)
    ThreadingHTTPServer(("0.0.0.0", PORT), H).serve_forever()
