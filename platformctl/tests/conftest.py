from __future__ import annotations

import asyncio

import pyotp
import pytest
from fastapi.testclient import TestClient

from platformctl.web import app as app_module
from platformctl.web import audit, auth, config, notify


@pytest.fixture
def isolated_config(tmp_path, monkeypatch):
    """Point every credential/state file at a throwaway directory for this test."""
    config_dir = tmp_path / "control-plane"
    config_dir.mkdir()

    credentials_file = config_dir / "credentials.json"
    session_secret_file = config_dir / "session_secret"
    notify_config_file = config_dir / "notify.json"
    audit_log_file = config_dir / "audit.log"
    sessions_file = config_dir / "active_sessions.json"

    monkeypatch.setattr(config, "CONFIG_DIR", config_dir)
    monkeypatch.setattr(config, "CREDENTIALS_FILE", credentials_file)
    monkeypatch.setattr(config, "SESSION_SECRET_FILE", session_secret_file)
    monkeypatch.setattr(config, "NOTIFY_CONFIG_FILE", notify_config_file)
    monkeypatch.setattr(config, "AUDIT_LOG_FILE", audit_log_file)
    monkeypatch.setattr(config, "SESSIONS_FILE", sessions_file)

    monkeypatch.setattr(auth, "CREDENTIALS_FILE", credentials_file)
    monkeypatch.setattr(auth, "SESSION_SECRET_FILE", session_secret_file)
    monkeypatch.setattr(auth, "SESSIONS_FILE", sessions_file, raising=False)
    monkeypatch.setattr(notify, "NOTIFY_CONFIG_FILE", notify_config_file)
    monkeypatch.setattr(audit, "AUDIT_LOG_FILE", audit_log_file)

    # auth._failed_attempts is process-global, in-memory state (by design, so a
    # restart clears lockouts) - it must not leak between tests either.
    monkeypatch.setattr(auth, "_failed_attempts", {})

    return config_dir


@pytest.fixture
def enrolled(isolated_config):
    """An enrolled account: username 'andrew', password below, valid TOTP secret."""
    password = "correct-horse-battery-staple"
    totp_secret = auth.enroll("andrew", password)
    return {"username": "andrew", "password": password, "totp_secret": totp_secret}


@pytest.fixture
def totp_code(enrolled):
    return pyotp.TOTP(enrolled["totp_secret"]).now()


async def _noop_poller(bus: notify.NotificationBus) -> None:
    await asyncio.Event().wait()


@pytest.fixture
def client(isolated_config, monkeypatch):
    monkeypatch.setattr(notify, "poller_loop", _noop_poller)
    app = app_module.create_app()
    with TestClient(app) as test_client:
        yield test_client
