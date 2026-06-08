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


def overlay_path(repo: Path, overlay: str, overlay_cfg: dict[str, Any]) -> Path:
    if "path" in overlay_cfg:
        return repo / overlay_cfg["path"]
    return repo / "k8s" / "overlays" / overlay


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
    overlays = k8s.get("overlays")
    if not isinstance(overlays, dict) or overlay not in overlays:
        raise SystemExit(f"Overlay '{overlay}' not defined under k8s.overlays in system.yaml")

    overlay_cfg = overlays[overlay]
    config["overlay"] = overlay
    config["k8s_path"] = str(overlay_path(repo_path, overlay, overlay_cfg))
    config["namespace"] = config.get("namespace") or k8s.get("namespace")
    config["deployment"] = k8s.get("deployment")

    build = config.setdefault("build", {})
    homelab = build.setdefault("homelab", {})
    registry_image = build.setdefault("registry", {})
    config["compose_file"] = str(repo_path / build.get("compose_file", "docker-compose.yml"))
    config["compose_service"] = build.get("service", "app")
    config["image_local"] = homelab.get("image")
    config["image_registry"] = registry_image.get("image")
    config["image_tag"] = os.environ.get("IMAGE_TAG") or registry_image.get("tag", "latest")
    config["registry_push"] = bool(registry_image.get("push", False))
    config["import_nodes"] = overlay_cfg.get("import_nodes", "")

    nginx = config.get("nginx") or {}
    config["nginx_app"] = nginx.get("name") if isinstance(nginx, dict) else None

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
        print(f"OK: {app_name} ({config['repo']})")
        return

    if command == "get" and len(sys.argv) == 4:
        print(get_nested(config, sys.argv[3]))
        return

    raise SystemExit("Usage: app_config.py <app> <export|validate|get <key>>")


if __name__ == "__main__":
    main()
