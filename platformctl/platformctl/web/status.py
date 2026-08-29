from __future__ import annotations

import json
import os
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from ..cli import run

REPO_ROOT = Path(__file__).resolve().parents[3]


def _json_lines(text: str) -> list[dict[str, Any]]:
    """Parse `docker ... --format json` output: one JSON object per line."""
    items: list[dict[str, Any]] = []
    for line in text.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            items.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return items


def is_wsl() -> bool:
    try:
        return "microsoft" in Path("/proc/version").read_text(encoding="utf-8").lower()
    except OSError:
        return False


# --- Dev services (development/catalog.json, Compose project "platform-dev") ---


def dev_services_status() -> list[dict[str, Any]]:
    rc, out = run(
        ["docker", "compose", "-p", "platform-dev", "ps", "-a", "--format", "json"],
        timeout=20,
    )
    if rc != 0:
        return []
    return [
        {
            "name": c.get("Name"),
            "service": c.get("Service"),
            "image": c.get("Image"),
            "state": c.get("State"),
            "status": c.get("Status"),
            "health": c.get("Health") or "",
            "ports": c.get("Publishers") or [],
        }
        for c in _json_lines(out)
    ]


# --- ai-runtime (separate Compose project, Ollama) ---


def ai_runtime_status() -> list[dict[str, Any]]:
    rc, out = run(
        [
            "docker",
            "ps",
            "-a",
            "--filter",
            "label=com.docker.compose.project=ai-runtime",
            "--format",
            "json",
        ],
        timeout=15,
    )
    if rc != 0:
        return []
    return [
        {"name": c.get("Names"), "image": c.get("Image"), "status": c.get("Status")}
        for c in _json_lines(out)
    ]


# --- Lab clusters (labs/catalog.json) ---


def labs_status() -> list[dict[str, Any]]:
    catalog_path = REPO_ROOT / "labs" / "catalog.json"
    if not catalog_path.exists():
        return []
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))
    ns_prefix = catalog.get("kubernetes", {}).get("namespacePrefix", "platform-lab")

    results: list[dict[str, Any]] = []
    for lab_id, lab in catalog.get("labs", {}).items():
        entry: dict[str, Any] = {"id": lab_id, "purpose": lab.get("purpose", ""), "containers": []}
        lab_path = REPO_ROOT / lab.get("path", "")

        if "docker" in lab.get("runtimes", []):
            compose_file = lab_path / "docker" / "compose.yaml"
            if compose_file.exists():
                rc, out = run(
                    [
                        "docker",
                        "compose",
                        "-p",
                        f"platform-lab-{lab_id}",
                        "-f",
                        str(compose_file),
                        "ps",
                        "-a",
                        "--format",
                        "json",
                    ],
                    timeout=20,
                )
                if rc == 0:
                    entry["containers"] = [
                        {"name": c.get("Name"), "state": c.get("State"), "status": c.get("Status")}
                        for c in _json_lines(out)
                    ]

        if "kubernetes" in lab.get("runtimes", []):
            namespace = f"{ns_prefix}-{lab_id}"
            rc, out = run(
                ["kubectl", "get", "pods", "-n", namespace, "-o", "json"],
                timeout=10,
            )
            if rc == 0:
                try:
                    pods = json.loads(out).get("items", [])
                    entry["kubernetes_pods"] = [
                        {
                            "name": p["metadata"]["name"],
                            "phase": p.get("status", {}).get("phase"),
                        }
                        for p in pods
                    ]
                except (json.JSONDecodeError, KeyError):
                    pass

        results.append(entry)
    return results


# --- Governed projects + their Dev Containers ---


def _expand(path: str) -> Path:
    return Path(path.replace("~", str(Path.home()), 1) if path.startswith("~") else path)


def governed_projects_status() -> list[dict[str, Any]]:
    policy_path = REPO_ROOT / "policy" / "development.json"
    if not policy_path.exists():
        return []
    policy = json.loads(policy_path.read_text(encoding="utf-8"))
    roots = [_expand(r) for r in policy.get("projectRoots", [])]

    rc, out = run(
        ["docker", "ps", "--filter", "label=devcontainer.local_folder", "--format", "json"],
        timeout=15,
    )
    running_by_folder: dict[str, dict[str, Any]] = {}
    if rc == 0:
        for c in _json_lines(out):
            labels = c.get("Labels", "")
            match = re.search(r"devcontainer\.local_folder=([^,]+)", labels)
            if match:
                running_by_folder[str(Path(match.group(1)))] = {
                    "name": c.get("Names"),
                    "status": c.get("Status"),
                }

    projects: list[dict[str, Any]] = []
    for root in roots:
        if not root.is_dir():
            continue
        for project_dir in sorted(root.glob("*")):
            meta_file = project_dir / ".platformctl" / "project.json"
            if not meta_file.exists():
                continue
            try:
                meta = json.loads(meta_file.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                meta = {}
            container = running_by_folder.get(str(project_dir))
            projects.append(
                {
                    "path": str(project_dir),
                    "name": meta.get("name", project_dir.name),
                    "template": meta.get("template"),
                    "area": meta.get("area"),
                    "dev_container_running": container is not None,
                    "dev_container_status": container.get("status") if container else None,
                }
            )
    return projects


# --- Background jobs (autosync / autoupgrade) ---


def _parse_ms_date(value: str | None) -> str | None:
    if not value:
        return None
    match = re.match(r"/Date\((\d+)\)/", value)
    if not match:
        return value
    ts = int(match.group(1)) / 1000
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat()


def _background_jobs_windows() -> list[dict[str, Any]]:
    jobs = []
    for name in ("WorkstationSetupAutoSync", "WorkstationAutoUpgrade"):
        cmd = [
            "powershell.exe",
            "-NoLogo",
            "-NoProfile",
            "-Command",
            f"Get-ScheduledTaskInfo -TaskName '{name}' -ErrorAction SilentlyContinue | "
            "Select-Object TaskName,LastRunTime,LastTaskResult,NextRunTime | ConvertTo-Json -Compress",
        ]
        rc, out = run(cmd, timeout=15)
        info: dict[str, Any] = {}
        if out.strip():
            try:
                info = json.loads(out)
            except json.JSONDecodeError:
                info = {}
        last_result = info.get("LastTaskResult")
        jobs.append(
            {
                "name": name,
                "installed": bool(info),
                "last_run": _parse_ms_date(info.get("LastRunTime")),
                "last_result": last_result,
                "next_run": _parse_ms_date(info.get("NextRunTime")),
                "healthy": bool(info) and last_result == 0,
            }
        )
    return jobs


def _background_jobs_linux() -> list[dict[str, Any]]:
    jobs = []
    for unit in ("workstation-autosync.timer", "workstation-autoupgrade.timer"):
        rc, _ = run(["systemctl", "--user", "is-active", "--quiet", unit], timeout=10)
        installed = rc in (0, 3)  # 3 = inactive but known unit
        service = unit.replace(".timer", ".service")
        result_rc, result_out = run(
            ["systemctl", "--user", "show", service, "--property=Result", "--value"], timeout=10
        )
        result = result_out.strip() if result_rc == 0 else None
        jobs.append(
            {
                "name": unit,
                "installed": installed,
                "last_run": None,
                "last_result": result,
                "next_run": None,
                "healthy": installed and (result in (None, "", "success")),
            }
        )
    return jobs


def _background_jobs_macos() -> list[dict[str, Any]]:
    jobs = []
    for label in ("com.workstation.autosync", "com.workstation.autoupgrade"):
        rc, _ = run(["launchctl", "list", label], timeout=10)
        jobs.append(
            {
                "name": label,
                "installed": rc == 0,
                "last_run": None,
                "last_result": None,
                "next_run": None,
                "healthy": rc == 0,
            }
        )
    return jobs


def background_jobs_status() -> list[dict[str, Any]]:
    if is_wsl():
        return _background_jobs_windows()
    if sys.platform == "darwin":
        return _background_jobs_macos()
    return _background_jobs_linux()


# --- Resource utilization ---


def resource_utilization() -> dict[str, Any]:
    import psutil

    mem = psutil.virtual_memory()
    disk = psutil.disk_usage(str(Path.home()))
    host = {
        "cpu_percent": psutil.cpu_percent(interval=0.2),
        "memory_percent": mem.percent,
        "memory_available_gib": round(mem.available / (1024**3), 1),
        "disk_percent": disk.percent,
        "disk_free_gib": round(disk.free / (1024**3), 1),
        "scope": "WSL2 VM, not native Windows host" if is_wsl() else "native host",
    }

    rc, out = run(
        [
            "docker",
            "stats",
            "--no-stream",
            "--format",
            "json",
        ],
        timeout=15,
    )
    containers = []
    if rc == 0:
        for c in _json_lines(out):
            containers.append(
                {
                    "name": c.get("Name"),
                    "cpu": c.get("CPUPerc"),
                    "memory": c.get("MemPerc"),
                    "memory_usage": c.get("MemUsage"),
                }
            )

    return {"host": host, "containers": containers}
