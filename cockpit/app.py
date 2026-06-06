#!/usr/bin/env python3
"""Fleet Cockpit backend — dependency-free web app for managing the homelab GPU
cluster. Talks to the Kubernetes API with the pod's ServiceAccount and scrapes
DCGM exporters directly for live per-GPU telemetry (util/temp/VRAM/power).
Set HOMELAB_DEMO=1 to run locally with animated fake data."""
import json, os, random, re, ssl, threading, time, urllib.error, urllib.parse, urllib.request
from concurrent.futures import ThreadPoolExecutor
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

PORT = int(os.environ.get("PORT", "8090"))
DEMO = os.environ.get("HOMELAB_DEMO") == "1"
API  = "https://kubernetes.default.svc"
SA   = "/var/run/secrets/kubernetes.io/serviceaccount"
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
            cards.append({
                "id": f"{n['name']}:{idx}",
                "node": n["name"],
                "node_ready": n["ready"],
                "idx": idx,
                "product": n.get("gpu_product", "-"),
                "tier": n.get("tier", "-"),
                "vram_gb": n.get("vram", "-"),
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
        },
        "usage": {
            "gpu_util_pct": gpu_util,
            "gpu_alloc_pct": alloc_pct,
            "vram_pct": vram_pct,
            "workloads": len(workloads),
            "workload_gpus": wl_gpu,
            "gpu_max_pct": round(max(utils)) if utils else 0,
        },
        "tiers": tiers,
    }

def overview():
    if DEMO:
        tel = demo_telemetry()
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
    nodes = []
    for n in nodes_raw:
        lab, st = n["metadata"].get("labels", {}), n["status"]
        nodes.append({
            "name": n["metadata"]["name"],
            "ready": any(c["type"] == "Ready" and c["status"] == "True"
                         for c in st.get("conditions", [])),
            "control": lab.get("node-role.homelab/control-plane") == "true"
                       or "node-role.kubernetes.io/control-plane" in lab,
            "unschedulable": bool(n["spec"].get("unschedulable", False)),
            "cpu": st.get("allocatable", {}).get("cpu", "?"),
            "ram": str(round(int(str(st.get("allocatable", {}).get("memory", "0Ki"))[:-2] or 0) / 1048576)),
            "gpu_product": lab.get("gpu.homelab/product", lab.get("nvidia.com/gpu.product", "-")),
            "gpus": int(st.get("allocatable", {}).get("nvidia.com/gpu", "0") or 0),
            "vram": _node_vram_gb(lab),
            "cc": _node_compute_cap(lab),
            "tier": lab.get("gpu.homelab/tier", "-"),
            "gpu_used": used.get(n["metadata"]["name"], 0)})
    wl = [{"ns": d["metadata"]["namespace"], "name": d["metadata"]["name"], "kind": "Deployment",
           "replicas": d["spec"].get("replicas", 0),
           "ready": d["status"].get("readyReplicas", 0) or 0,
           "gpus": sum(int(c.get("resources", {}).get("limits", {}).get("nvidia.com/gpu", "0") or 0)
                       for c in d["spec"]["template"]["spec"].get("containers", []))}
          for d in deps_raw if d["metadata"]["namespace"] not in SYS_NS]
    tel = telemetry()
    gpus = flatten_gpus(nodes, tel, pods_by_node)
    drains = drain_snapshot()
    return {"nodes": nodes, "workloads": wl, "pods_by_node": pods_by_node,
            "telemetry": tel, "gpus": gpus, "drains": drains,
            "cluster": cluster_summary(nodes, gpus, wl, drains, tel)}

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

ACTIONS = {"/api/scale": act_scale, "/api/cordon": act_cordon,
           "/api/label": act_label, "/api/drain": act_drain}

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
