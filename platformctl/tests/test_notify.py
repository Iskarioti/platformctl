from __future__ import annotations

import asyncio

import pytest

from platformctl.web import notify


def test_default_config_when_missing(isolated_config):
    config = notify.load_notify_config()
    assert config["enabled_channels"] == ["in_app"]
    assert config["cpu_threshold"] == 90


def test_save_then_load_merges_with_defaults(isolated_config):
    notify.save_notify_config({"enabled_channels": ["in_app", "email"], "cpu_threshold": 50})
    config = notify.load_notify_config()
    assert config["enabled_channels"] == ["in_app", "email"]
    assert config["cpu_threshold"] == 50
    # Fields not in the saved partial config still fall back to defaults.
    assert config["poll_interval_seconds"] == 30
    assert config["smtp"]["port"] == 587


def test_bus_publish_delivers_to_subscribers():
    bus = notify.NotificationBus()
    q1 = bus.subscribe()
    q2 = bus.subscribe()
    bus.publish({"level": "warning", "message": "hi"})
    assert q1.get_nowait() == {"level": "warning", "message": "hi"}
    assert q2.get_nowait() == {"level": "warning", "message": "hi"}


def test_bus_unsubscribe_stops_delivery():
    bus = notify.NotificationBus()
    q = bus.subscribe()
    bus.unsubscribe(q)
    bus.publish({"level": "info", "message": "should not arrive"})
    assert q.empty()


def test_check_jobs_fires_on_unhealthy_transition():
    bus = notify.NotificationBus()
    q = bus.subscribe()
    previous: dict[str, bool] = {}
    config = {"enabled_channels": ["in_app"]}
    jobs = [{"name": "WorkstationSetupAutoSync", "installed": True, "healthy": False}]

    notify._check_jobs(bus, ["in_app"], config, previous, jobs_fn=lambda: jobs)
    event = q.get_nowait()
    assert "unhealthy" in event["message"]
    assert previous["WorkstationSetupAutoSync"] is False

    # Second consecutive unhealthy cycle should NOT re-fire (edge-triggered).
    notify._check_jobs(bus, ["in_app"], config, previous, jobs_fn=lambda: jobs)
    assert q.empty()


def test_check_jobs_does_not_fire_when_not_installed():
    bus = notify.NotificationBus()
    q = bus.subscribe()
    jobs = [{"name": "WorkstationAutoUpgrade", "installed": False, "healthy": False}]
    notify._check_jobs(bus, ["in_app"], {}, {}, jobs_fn=lambda: jobs)
    assert q.empty()


def test_check_services_fires_only_on_stop_transition():
    bus = notify.NotificationBus()
    q = bus.subscribe()
    previous: dict[str, bool] = {"dev-redis": True}
    services = [{"name": "dev-redis", "state": "exited"}]

    notify._check_services(bus, ["in_app"], {}, previous, services_fn=lambda: services)
    event = q.get_nowait()
    assert "stopped" in event["message"]

    # Now it's already known-stopped; going from stopped->stopped must not re-fire.
    notify._check_services(bus, ["in_app"], {}, previous, services_fn=lambda: services)
    assert q.empty()


def test_check_resources_fires_once_per_breach_episode():
    bus = notify.NotificationBus()
    q = bus.subscribe()
    config = {"cpu_threshold": 90, "memory_threshold": 90}
    high = {"host": {"cpu_percent": 95, "memory_percent": 10}}
    low = {"host": {"cpu_percent": 10, "memory_percent": 10}}

    cpu_b, mem_b = notify._check_resources(bus, ["in_app"], config, False, False, resources_fn=lambda: high)
    assert cpu_b is True
    assert "CPU" in q.get_nowait()["message"]

    # Still breached on the next cycle: no repeat notification.
    cpu_b, mem_b = notify._check_resources(bus, ["in_app"], config, cpu_b, mem_b, resources_fn=lambda: high)
    assert q.empty()

    # Drops back down, then breaches again: should re-fire.
    cpu_b, mem_b = notify._check_resources(bus, ["in_app"], config, cpu_b, mem_b, resources_fn=lambda: low)
    assert cpu_b is False
    cpu_b, mem_b = notify._check_resources(bus, ["in_app"], config, cpu_b, mem_b, resources_fn=lambda: high)
    assert cpu_b is True
    assert "CPU" in q.get_nowait()["message"]


def test_send_email_returns_false_without_host():
    assert notify.send_email("subject", "body", {"host": "", "to_addr": ""}) is False


class _FakeAlertResponse:
    def __init__(self, results):
        self._results = results

    def raise_for_status(self):
        pass

    def json(self):
        return {"status": "success", "data": {"resultType": "vector", "result": self._results}}


class _FakeAsyncClient:
    def __init__(self, results):
        self._results = results

    async def __aenter__(self):
        return self

    async def __aexit__(self, *exc):
        return False

    async def get(self, url, params=None):
        return _FakeAlertResponse(self._results)


async def test_check_prometheus_alerts_unreachable_is_graceful(monkeypatch):
    def boom(timeout=5):
        raise notify.httpx.ConnectError("connection refused")

    monkeypatch.setattr(notify.httpx, "AsyncClient", boom)
    bus = notify.NotificationBus()
    q = bus.subscribe()
    previous: set[str] = set()

    await notify._check_prometheus_alerts(bus, ["in_app"], {}, previous)
    assert previous == set()
    assert q.empty()


async def test_check_prometheus_alerts_fires_on_new_alert_and_not_on_repeat(monkeypatch):
    result = [
        {
            "metric": {
                "alertname": "ScrapeTargetDown",
                "alertstate": "firing",
                "job": "node-exporter",
            }
        }
    ]
    monkeypatch.setattr(notify.httpx, "AsyncClient", lambda timeout=5: _FakeAsyncClient(result))

    bus = notify.NotificationBus()
    q = bus.subscribe()
    previous: set[str] = set()

    await notify._check_prometheus_alerts(bus, ["in_app"], {}, previous)
    assert "ScrapeTargetDown/node-exporter" in previous
    event = q.get_nowait()
    assert "ScrapeTargetDown" in event["message"]

    # Same alert still firing on the next cycle: must not re-notify.
    await notify._check_prometheus_alerts(bus, ["in_app"], {}, previous)
    assert q.empty()


def test_send_os_native_never_raises(monkeypatch):
    def boom(*a, **k):
        raise OSError("no such binary")

    monkeypatch.setattr(notify.subprocess, "run", boom)
    notify.send_os_native("title", "message")  # must not raise
