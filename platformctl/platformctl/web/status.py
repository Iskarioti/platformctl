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
            if not project_dir.is_dir():
                continue

            meta_file = project_dir / ".platformctl" / "project.json"
            container = running_by_folder.get(str(project_dir))

            if meta_file.exists():
                try:
                    meta = json.loads(meta_file.read_text(encoding="utf-8"))
                except json.JSONDecodeError:
                    meta = {}
                projects.append(
                    {
                        "path": str(project_dir),
                        "name": meta.get("name", project_dir.name),
                        "template": meta.get("template"),
                        "area": meta.get("area"),
                        "dev_container_running": container is not None,
                        "dev_container_status": container.get("status") if container else None,
                        "tracked": True,
                    }
                )
            elif (project_dir / ".git").exists():
                # A real project (it's a git repo) that was cloned or already
                # existed rather than created via "workstation project init" -
                # no .platformctl/project.json means it's otherwise invisible
                # here. Surface it anyway so there's a prompt to adopt it
                # (see "workstation project adopt"), rather than it silently
                # not being tracked at all.
                projects.append(
                    {
                        "path": str(project_dir),
                        "name": project_dir.name,
                        "template": None,
                        "area": None,
                        "dev_container_running": container is not None,
                        "dev_container_status": container.get("status") if container else None,
                        "tracked": False,
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


# --- Toolchain health: security scan freshness, research toolchain,
#     template drift. The Hybrid role review's own finding: the dashboard's
#     one pane of glass stopped at platform ops - no panel here told you
#     whether a scan was stale, the research toolchain was installed, or a
#     governed project's template had moved on. Read the same state
#     "workstation doctor" already does, not a new source of truth. ---


def _security_scan_freshness() -> dict[str, Any]:
    scan_path = REPO_ROOT / ".state" / "security" / "last-scan.json"
    if not scan_path.exists():
        return {"ran": False, "healthy": False}
    try:
        scan = json.loads(scan_path.read_text(encoding="utf-8"))
        scanned_at = datetime.fromisoformat(scan["scannedAtUtc"].replace("Z", "+00:00"))
        age_days = (datetime.now(timezone.utc) - scanned_at).days
        return {
            "ran": True,
            "target": scan.get("target"),
            "age_days": age_days,
            "findings_count": scan.get("findingsCount"),
            "healthy": age_days <= 14,
        }
    except (json.JSONDecodeError, KeyError, ValueError):
        return {"ran": False, "healthy": False}


def _research_toolchain() -> dict[str, Any]:
    script = REPO_ROOT / "scripts" / "posix" / "research.sh"
    if not script.exists():
        return {"available": False, "pass_count": 0, "total": 0, "missing": []}
    rc, out = run(["bash", str(script), "doctor"], timeout=20)
    passed = [line.split(None, 2)[1] for line in out.splitlines() if line.startswith("PASS")]
    missing = [line.split(None, 2)[1] for line in out.splitlines() if line.startswith("MISS")]
    total = len(passed) + len(missing)
    return {
        "available": True,
        "pass_count": len(passed),
        "total": total,
        "missing": missing,
        "healthy": total > 0 and not missing,
    }


def _template_drift() -> dict[str, Any]:
    catalog_path = REPO_ROOT / "templates" / "catalog.json"
    policy_path = REPO_ROOT / "policy" / "development.json"
    if not (catalog_path.exists() and policy_path.exists()):
        return {"total": 0, "outdated": 0, "healthy": True}
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))["templates"]
    policy = json.loads(policy_path.read_text(encoding="utf-8"))

    total = 0
    outdated = 0
    outdated_projects: list[str] = []
    for raw_root in policy.get("projectRoots", []):
        proj_root = _expand(raw_root)
        if not proj_root.is_dir():
            continue
        for child in proj_root.iterdir():
            meta_path = child / ".platformctl" / "project.json"
            if not meta_path.exists():
                continue
            total += 1
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            entry = catalog.get(meta.get("template"))
            if entry and meta.get("templateVersion") != entry.get("version"):
                outdated += 1
                outdated_projects.append(meta.get("name", child.name))
    return {
        "total": total,
        "outdated": outdated,
        "outdated_projects": outdated_projects,
        "healthy": outdated == 0,
    }


def _paper_builds() -> dict[str, Any]:
    # "Did the paper build" - the Hybrid role review's own example of what
    # this dashboard's one pane of glass couldn't answer. A cheap, real,
    # local proxy for CI build status: for every governed project scaffolded
    # from research-paper, paper/main.pdf existing and newer than
    # paper/main.tex means the last local `make paper` succeeded since the
    # source last changed. Not a substitute for the real CI status (this
    # doesn't call the GitHub API), just what's actually checkable without
    # one - the same "read local state, don't invent a new source of truth"
    # principle every other panel here already follows.
    policy_path = REPO_ROOT / "policy" / "development.json"
    if not policy_path.exists():
        return {"total": 0, "stale": 0, "papers": [], "healthy": True}
    policy = json.loads(policy_path.read_text(encoding="utf-8"))

    total = 0
    stale = 0
    papers: list[dict[str, Any]] = []
    for raw_root in policy.get("projectRoots", []):
        proj_root = _expand(raw_root)
        if not proj_root.is_dir():
            continue
        for child in proj_root.iterdir():
            meta_path = child / ".platformctl" / "project.json"
            if not meta_path.exists():
                continue
            try:
                meta = json.loads(meta_path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                continue
            if meta.get("template") != "research-paper":
                continue
            tex_path = child / "paper" / "main.tex"
            pdf_path = child / "paper" / "main.pdf"
            if not tex_path.exists():
                continue
            total += 1
            built = pdf_path.exists() and pdf_path.stat().st_mtime >= tex_path.stat().st_mtime
            if not built:
                stale += 1
            papers.append({"name": meta.get("name", child.name), "built": built})
    return {"total": total, "stale": stale, "papers": papers, "healthy": stale == 0}


def toolchain_status() -> dict[str, Any]:
    return {
        "security_scan": _security_scan_freshness(),
        "research_toolchain": _research_toolchain(),
        "paper_builds": _paper_builds(),
        "template_drift": _template_drift(),
    }


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
