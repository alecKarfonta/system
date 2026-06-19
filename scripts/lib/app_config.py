#!/usr/bin/env python3
"""Load and validate merged deploy config: system registry + repo system.yaml."""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path
from typing import Any

import yaml

SYSTEM_ROOT = Path(__file__).resolve().parents[2]
VALID_OVERLAYS = {"homelab", "production"}
VALID_DELIVERY = {"import", "registry"}
VALID_STORAGE = {"emptydir", "pvc"}


def load_yaml(path: Path) -> dict[str, Any]:
    with path.open() as handle:
        data = yaml.safe_load(handle)
    return data if isinstance(data, dict) else {}


def expand_path(value: str) -> str:
    return os.path.expanduser(value)


def deep_merge(base: dict[str, Any], override: dict[str, Any]) -> dict[str, Any]:
    merged = dict(base)
    for key, value in override.items():
        if key in merged and isinstance(merged[key], dict) and isinstance(value, dict):
            merged[key] = deep_merge(merged[key], value)
        else:
            merged[key] = value
    return merged


def overlay_path(
    repo: Path,
    overlay: str,
    overlay_cfg: dict[str, Any],
    storage_sessions: str = "emptydir",
) -> Path:
    if "path" in overlay_cfg:
        return repo / overlay_cfg["path"]
    if overlay == "homelab" and storage_sessions == "pvc":
        pvc_path = repo / "k8s" / "overlays" / "homelab-pvc"
        if (pvc_path / "kustomization.yaml").exists():
            return pvc_path
    return repo / "k8s" / "overlays" / overlay


def _storage_sessions_type(config: dict[str, Any]) -> str:
    env_override = os.environ.get("SESSIONS_STORAGE", "").strip().lower()
    if env_override:
        return env_override
    storage = config.get("storage") or {}
    sessions = storage.get("sessions") or {}
    return str(sessions.get("type", "emptyDir")).lower()


def _homelab_delivery(config: dict[str, Any]) -> str:
    env_override = os.environ.get("HOMELAB_DELIVERY", "").strip().lower()
    if env_override:
        return env_override
    build = config.get("build") or {}
    homelab = build.get("homelab") or {}
    return str(homelab.get("delivery", "import")).lower()


def load_config(app_name: str, system_root: Path | None = None) -> dict[str, Any]:
    root = system_root or SYSTEM_ROOT
    registry_path = root / "apps" / f"{app_name}.yaml"
    if not registry_path.exists():
        raise SystemExit(f"App not registered: {registry_path}")

    registry = load_yaml(registry_path)
    repo = expand_path(registry.get("repo", ""))
    if not repo:
        raise SystemExit(f"apps/{app_name}.yaml must set repo")
    repo_path = Path(repo)
    if not repo_path.is_dir():
        raise SystemExit(f"Repo not found: {repo_path}")

    contract_path = repo_path / "system.yaml"
    if not contract_path.exists():
        raise SystemExit(f"Missing repo contract: {contract_path}")

    config = deep_merge(load_yaml(contract_path), registry)
    config["app"] = app_name
    config["repo"] = str(repo_path)

    k8s = config.setdefault("k8s", {})
    overlay = os.environ.get("K8S_OVERLAY") or k8s.get("default_overlay", "homelab")
    if overlay not in VALID_OVERLAYS:
        raise SystemExit(
            f"Overlay '{overlay}' is not supported — use homelab or production"
        )
    overlays = k8s.get("overlays")
    if not isinstance(overlays, dict) or overlay not in overlays:
        raise SystemExit(f"Overlay '{overlay}' not defined under k8s.overlays in system.yaml")

    overlay_cfg = overlays[overlay]
    config["overlay"] = overlay
    config["k8s_path"] = str(
        overlay_path(repo_path, overlay, overlay_cfg, _storage_sessions_type(config))
    )
    config["namespace"] = config.get("namespace") or k8s.get("namespace")
    config["deployment"] = k8s.get("deployment")

    build = config.setdefault("build", {})
    homelab = build.setdefault("homelab", {})
    homelab_registry = homelab.setdefault("registry", {})
    prod_registry = build.setdefault("registry", {})
    config["compose_file"] = str(repo_path / build.get("compose_file", "docker-compose.yml"))
    config["compose_service"] = build.get("service", "app")
    config["image_local"] = homelab.get("image")
    config["image_registry"] = prod_registry.get("image")
    config["image_tag"] = os.environ.get("IMAGE_TAG") or prod_registry.get("tag", "latest")
    config["registry_push"] = bool(prod_registry.get("push", False))
    config["import_nodes"] = overlay_cfg.get("import_nodes", "")
    config["homelab_delivery"] = _homelab_delivery(config)
    config["homelab_registry_repo"] = homelab_registry.get("repo") or f"{app_name}/{app_name}"
    config["homelab_registry_tag"] = homelab_registry.get("tag") or "local"

    storage = config.setdefault("storage", {})
    sessions = storage.setdefault("sessions", {})
    config["storage_sessions"] = _storage_sessions_type(config)
    config["storage_sessions_size"] = sessions.get("size", "10Gi")

    nginx = config.get("nginx") or {}
    if isinstance(nginx, dict):
        config["nginx_app"] = nginx.get("name")
        config["nginx_host"] = nginx.get("host", "auto")
        config["nginx_service"] = nginx.get("service") or config.get("deployment")
        config["nginx_service_port"] = nginx.get("service_port", "http")
        config["nginx_port"] = nginx.get("port")
        config["nginx_upstream"] = nginx.get("upstream")
    else:
        config["nginx_app"] = None
        config["nginx_host"] = "auto"
        config["nginx_service"] = config.get("deployment")
        config["nginx_service_port"] = "http"

    return config


def validate_config(config: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    repo = Path(config["repo"])

    if not (repo / "system.yaml").exists():
        errors.append("system.yaml missing in repo root")

    k8s_path = Path(config["k8s_path"])
    if not (k8s_path / "kustomization.yaml").exists():
        errors.append(f"missing kustomization: {k8s_path}/kustomization.yaml")

    if not (repo / "k8s" / "base" / "kustomization.yaml").exists():
        errors.append("missing k8s/base/kustomization.yaml")

    compose_file = Path(config["compose_file"])
    if not compose_file.exists():
        errors.append(f"missing compose file: {compose_file}")

    if not config.get("namespace"):
        errors.append("namespace is required in system.yaml")
    if not config.get("deployment"):
        errors.append("k8s.deployment is required in system.yaml")

    overlay = config["overlay"]
    if overlay == "homelab" and not config.get("image_local"):
        errors.append("build.homelab.image is required for homelab overlay")
    if overlay == "production" and not config.get("image_registry"):
        errors.append("build.registry.image is required for production overlay")

    delivery = config.get("homelab_delivery", "import")
    if delivery not in VALID_DELIVERY:
        errors.append(f"build.homelab.delivery must be one of: {', '.join(sorted(VALID_DELIVERY))}")

    storage_type = config.get("storage_sessions", "emptydir")
    if storage_type not in VALID_STORAGE:
        errors.append(f"storage.sessions.type must be one of: emptyDir, pvc")

    legacy_overlay = repo / "k8s" / "overlays" / "cluster"
    if legacy_overlay.is_dir() and not (repo / "k8s" / "overlays" / "homelab").is_dir():
        errors.append(
            "found k8s/overlays/cluster — rename to homelab (standard overlay names: homelab, production)"
        )

    nginx_app = config.get("nginx_app")
    if nginx_app:
        root = SYSTEM_ROOT
        apps_root = root / "nginx" / "apps"
        # Per-site subdir layout (nginx/apps/<site>/<app>.conf) is the canonical
        # location; a flat nginx/apps/<app>.conf is accepted for backwards compat.
        found_app = next(
            (apps_root.rglob(f"{nginx_app}.conf")),
            None,
        )
        if not found_app:
            errors.append(
                f"missing nginx app config: nginx/apps/<site>/{nginx_app}.conf"
            )
        if not (root / "nginx" / "upstreams" / f"{nginx_app}.conf").exists():
            errors.append(f"missing nginx upstream: nginx/upstreams/{nginx_app}.conf")

    return errors


def get_nested(config: dict[str, Any], dotted: str) -> Any:
    value: Any = config
    for part in dotted.split("."):
        if not isinstance(value, dict) or part not in value:
            raise SystemExit(f"Unknown config key: {dotted}")
        value = value[part]
    return value


def main() -> None:
    if len(sys.argv) < 3:
        raise SystemExit("Usage: app_config.py <app> <export|validate|get <key>>")

    app_name = sys.argv[1]
    command = sys.argv[2]
    config = load_config(app_name)

    if command == "export":
        print(json.dumps(config))
        return

    if command == "validate":
        errors = validate_config(config)
        if errors:
            for error in errors:
                print(error, file=sys.stderr)
            raise SystemExit(1)
        print(f"OK: {app_name} ({config['repo']}) overlay={config['overlay']} "
              f"delivery={config['homelab_delivery']} storage={config['storage_sessions']}")
        return

    if command == "get" and len(sys.argv) == 4:
        print(get_nested(config, sys.argv[3]))
        return

    raise SystemExit("Usage: app_config.py <app> <export|validate|get <key>>")


if __name__ == "__main__":
    main()
