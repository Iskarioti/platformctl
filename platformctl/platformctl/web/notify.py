from __future__ import annotations

import asyncio
import json
import smtplib
import subprocess
import sys
from email.message import EmailMessage
from pathlib import Path
from typing import Any

import httpx

from .config import NOTIFY_CONFIG_FILE, secure_write
from .status import is_wsl, background_jobs_status, dev_services_status, resource_utilization

# The observability profile's documented default port (development/services/
# prometheus/defaults.env). Not read from that file at runtime: this app has
# no other reason to parse compose env files, and the same simplification
# already applies to the Grafana link hardcoded in templates/index.html.
PROMETHEUS_URL = "http://127.0.0.1:9090"

DEFAULT_CONFIG: dict[str, Any] = {
    "enabled_channels": ["in_app"],
    "poll_interval_seconds": 30,
    "cpu_threshold": 90,
    "memory_threshold": 90,
    "smtp": {
        "host": "",
        "port": 587,
        "username": "",
        "password": "",
        "use_tls": True,
        "from_addr": "",
        "to_addr": "",
    },
}


def load_notify_config() -> dict[str, Any]:
    if not NOTIFY_CONFIG_FILE.exists():
        return json.loads(json.dumps(DEFAULT_CONFIG))  # deep copy
    try:
        data = json.loads(NOTIFY_CONFIG_FILE.read_text(encoding="utf-8"))
    except json.JSONDecodeError:
        return json.loads(json.dumps(DEFAULT_CONFIG))
    merged = json.loads(json.dumps(DEFAULT_CONFIG))
    merged.update({k: v for k, v in data.items() if k != "smtp"})
    merged["smtp"].update(data.get("smtp", {}))
    return merged


def save_notify_config(config: dict[str, Any]) -> None:
    secure_write(NOTIFY_CONFIG_FILE, json.dumps(config, indent=2))


def send_os_native(title: str, message: str) -> None:
    try:
        if is_wsl():
            safe_message = message.replace("'", "''")
            safe_title = title.replace("'", "''")
            script = (
                "Add-Type -AssemblyName System.Windows.Forms; "
                "Add-Type -AssemblyName System.Drawing; "
                "$n = New-Object System.Windows.Forms.NotifyIcon; "
                "$n.Icon = [System.Drawing.SystemIcons]::Information; "
                "$n.Visible = $true; "
                f"$n.ShowBalloonTip(10000, '{safe_title}', '{safe_message}', "
                "[System.Windows.Forms.ToolTipIcon]::Warning); "
                "Start-Sleep -Seconds 6; $n.Dispose()"
            )
            subprocess.run(
                ["powershell.exe", "-NoLogo", "-NoProfile", "-Command", script],
                capture_output=True,
                timeout=15,
                check=False,
            )
        elif sys.platform == "darwin":
            subprocess.run(
                ["osascript", "-e", f'display notification "{message}" with title "{title}"'],
                capture_output=True,
                timeout=10,
                check=False,
            )
        else:
            subprocess.run(
                ["notify-send", title, message],
                capture_output=True,
                timeout=10,
                check=False,
            )
    except (OSError, subprocess.TimeoutExpired):
        pass


def send_email(subject: str, body: str, smtp: dict[str, Any]) -> bool:
    if not smtp.get("host") or not smtp.get("to_addr"):
        return False
    msg = EmailMessage()
    msg["Subject"] = subject
    msg["From"] = smtp.get("from_addr") or smtp["username"]
    msg["To"] = smtp["to_addr"]
    msg.set_content(body)
    try:
        with smtplib.SMTP(smtp["host"], int(smtp.get("port", 587)), timeout=15) as server:
            if smtp.get("use_tls", True):
                server.starttls()
            if smtp.get("username"):
                server.login(smtp["username"], smtp["password"])
            server.send_message(msg)
        return True
    except (smtplib.SMTPException, OSError):
        return False


class NotificationBus:
    """In-process pub/sub so the poller can push to every open dashboard tab."""

    def __init__(self) -> None:
        self._subscribers: list[asyncio.Queue[dict[str, Any]]] = []

    def subscribe(self) -> asyncio.Queue[dict[str, Any]]:
        queue: asyncio.Queue[dict[str, Any]] = asyncio.Queue(maxsize=50)
        self._subscribers.append(queue)
        return queue

    def unsubscribe(self, queue: asyncio.Queue[dict[str, Any]]) -> None:
        if queue in self._subscribers:
            self._subscribers.remove(queue)

    def publish(self, event: dict[str, Any]) -> None:
        for queue in list(self._subscribers):
            try:
                queue.put_nowait(event)
            except asyncio.QueueFull:
                pass


async def poller_loop(bus: NotificationBus) -> None:
    previous_jobs_healthy: dict[str, bool] = {}
    previous_services_running: dict[str, bool] = {}
    previous_firing_alerts: set[str] = set()
    cpu_breached = False
    memory_breached = False

    while True:
        config = load_notify_config()
        channels = config.get("enabled_channels", [])
        interval = max(10, int(config.get("poll_interval_seconds", 30)))

        try:
            # Each of these shells out (PowerShell/docker/psutil) and blocks for
            # real time. Run them off the event loop thread so a slow check
            # cycle never freezes every other request the dashboard is serving.
            await asyncio.to_thread(_check_jobs, bus, channels, config, previous_jobs_healthy)
            await asyncio.to_thread(_check_services, bus, channels, config, previous_services_running)
            cpu_breached, memory_breached = await asyncio.to_thread(
                _check_resources, bus, channels, config, cpu_breached, memory_breached
            )
            await _check_prometheus_alerts(bus, channels, config, previous_firing_alerts)
        except Exception as exc:  # noqa: BLE001 - the poller must never die
            bus.publish({"level": "error", "message": f"Notification poller error: {exc}"})

        await asyncio.sleep(interval)


def _notify(bus: NotificationBus, channels: list[str], config: dict[str, Any], level: str, message: str) -> None:
    if "in_app" in channels:
        bus.publish({"level": level, "message": message})
    if "os_native" in channels:
        send_os_native("platformctl control plane", message)
    if "email" in channels:
        send_email(f"platformctl: {message[:60]}", message, config.get("smtp", {}))


def _check_jobs(bus, channels, config, previous: dict[str, bool], jobs_fn=background_jobs_status) -> None:
    for job in jobs_fn():
        name = job["name"]
        healthy = bool(job["healthy"])
        was_healthy = previous.get(name)
        if job["installed"] and was_healthy is not False and not healthy:
            _notify(bus, channels, config, "warning", f"Background job unhealthy: {name}")
        previous[name] = healthy


def _check_services(bus, channels, config, previous: dict[str, bool], services_fn=dev_services_status) -> None:
    current = {c["name"]: c["state"] == "running" for c in services_fn()}
    for name, running in current.items():
        was_running = previous.get(name)
        if was_running is True and not running:
            _notify(bus, channels, config, "warning", f"Dev service stopped: {name}")
    previous.clear()
    previous.update(current)


def _check_resources(bus, channels, config, cpu_breached: bool, memory_breached: bool, resources_fn=resource_utilization):
    data = resources_fn()["host"]
    cpu_threshold = float(config.get("cpu_threshold", 90))
    memory_threshold = float(config.get("memory_threshold", 90))

    cpu_now = data["cpu_percent"] > cpu_threshold
    memory_now = data["memory_percent"] > memory_threshold

    if cpu_now and not cpu_breached:
        _notify(bus, channels, config, "warning", f"CPU usage above {cpu_threshold}%: {data['cpu_percent']}%")
    if memory_now and not memory_breached:
        _notify(
            bus, channels, config, "warning", f"Memory usage above {memory_threshold}%: {data['memory_percent']}%"
        )
    return cpu_now, memory_now


async def _check_prometheus_alerts(bus, channels, config, previous_firing: set[str]) -> None:
    """Poll Prometheus's own alert-rule evaluation (development/services/prometheus/
    config/alert-rules.yml) rather than accepting an inbound webhook from Grafana:
    platformctl serve binds 127.0.0.1 only, which a container in a different network
    namespace (Grafana) could never reach anyway - pulling keeps the same direction
    as every other status check in this file."""
    try:
        async with httpx.AsyncClient(timeout=5) as client:
            response = await client.get(f"{PROMETHEUS_URL}/api/v1/query", params={"query": 'ALERTS{alertstate="firing"}'})
            response.raise_for_status()
            results = response.json().get("data", {}).get("result", [])
    except (httpx.HTTPError, ValueError):
        return  # observability profile not running, or Prometheus not reachable - not an error

    current_firing = {
        r["metric"].get("alertname", "unknown") + "/" + r["metric"].get("job", r["metric"].get("name", ""))
        for r in results
    }

    for alert in current_firing - previous_firing:
        _notify(bus, channels, config, "warning", f"Prometheus alert firing: {alert}")

    previous_firing.clear()
    previous_firing.update(current_firing)
