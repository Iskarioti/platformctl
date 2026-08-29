from __future__ import annotations


def test_root_redirects_to_login_when_no_session(client):
    response = client.get("/", follow_redirects=False)
    assert response.status_code == 303
    assert response.headers["location"] == "/login"


def test_setup_redirects_to_login_when_already_enrolled(client, enrolled):
    response = client.get("/setup", follow_redirects=False)
    assert response.status_code == 303
    assert response.headers["location"] == "/login"


def test_full_enroll_and_login_flow(client):
    response = client.post(
        "/setup",
        data={
            "username": "andrew",
            "password": "correct-horse-battery-staple",
            "confirm_password": "correct-horse-battery-staple",
        },
    )
    assert response.status_code == 200
    assert "Scan this QR code" in response.text

    import re

    match = re.search(r'<code class="secret">([A-Z0-9]+)</code>', response.text)
    assert match is not None
    totp_secret = match.group(1)

    import pyotp

    code = pyotp.TOTP(totp_secret).now()

    bad_login = client.post(
        "/login",
        data={"username": "andrew", "password": "wrong", "totp_code": code},
    )
    assert bad_login.status_code == 200
    assert "Invalid username" in bad_login.text

    good_login = client.post(
        "/login",
        data={"username": "andrew", "password": "correct-horse-battery-staple", "totp_code": code},
        follow_redirects=False,
    )
    assert good_login.status_code == 303
    assert good_login.headers["location"] == "/"
    assert "platformctl_session" in good_login.cookies

    home = client.get("/")
    assert home.status_code == 200
    assert "andrew" in home.text

    logout = client.get("/logout", follow_redirects=False)
    assert logout.status_code == 303
    after_logout = client.get("/", follow_redirects=False)
    assert after_logout.status_code == 303


def test_setup_rejects_short_password(client):
    response = client.post(
        "/setup",
        data={"username": "andrew", "password": "short", "confirm_password": "short"},
    )
    assert "at least 12 characters" in response.text


def test_setup_rejects_mismatched_passwords(client):
    response = client.post(
        "/setup",
        data={
            "username": "andrew",
            "password": "correct-horse-battery-staple",
            "confirm_password": "something-else-entirely",
        },
    )
    assert "do not match" in response.text


def test_login_backoff_returns_429_after_repeated_failures(client, enrolled):
    for _ in range(5):
        client.post(
            "/login",
            data={"username": "andrew", "password": "wrong", "totp_code": "000000"},
        )
    response = client.post(
        "/login",
        data={"username": "andrew", "password": "wrong", "totp_code": "000000"},
    )
    assert response.status_code == 429


def _login(client, enrolled, totp_code):
    return client.post(
        "/login",
        data={"username": enrolled["username"], "password": enrolled["password"], "totp_code": totp_code},
        follow_redirects=False,
    )


def test_panels_require_auth(client):
    for path in (
        "/panels/services",
        "/panels/ai-runtime",
        "/panels/labs",
        "/panels/projects",
        "/panels/jobs",
        "/panels/resources",
    ):
        response = client.get(path, follow_redirects=False)
        assert response.status_code == 303, path


def test_panels_render_when_authenticated(client, enrolled, totp_code, monkeypatch):
    _login(client, enrolled, totp_code)
    monkeypatch.setattr("platformctl.web.status.run", lambda cmd, timeout=30: (1, ""))
    for path in (
        "/panels/services",
        "/panels/ai-runtime",
        "/panels/labs",
        "/panels/projects",
        "/panels/jobs",
        "/panels/resources",
    ):
        response = client.get(path)
        assert response.status_code == 200, path


def test_run_unknown_command_is_rejected(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    response = client.get("/run-trigger/not-a-real-command")
    assert response.status_code == 404


def test_run_command_streams_output(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    with client.stream("GET", "/run/validate") as response:
        body = "".join(response.iter_text())
    assert "$ ./setup validate" in body
    assert "event: done" in body


def test_settings_requires_auth(client):
    response = client.get("/settings/notifications", follow_redirects=False)
    assert response.status_code == 303


def test_settings_save_and_reload(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    response = client.post(
        "/settings/notifications",
        data={
            "enabled_channels": ["in_app", "email"],
            "poll_interval_seconds": "45",
            "cpu_threshold": "80",
            "memory_threshold": "85",
            "smtp_host": "smtp.example.com",
            "smtp_port": "587",
            "smtp_username": "me@example.com",
            "smtp_password": "hunter2",
            "smtp_from_addr": "me@example.com",
            "smtp_to_addr": "alerts@example.com",
        },
    )
    assert response.status_code == 200
    assert "Saved" in response.text

    from platformctl.web import notify

    config = notify.load_notify_config()
    assert config["enabled_channels"] == ["in_app", "email"]
    assert config["cpu_threshold"] == 80.0
    assert config["smtp"]["host"] == "smtp.example.com"


def test_settings_save_blank_password_keeps_existing(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    client.post(
        "/settings/notifications",
        data={
            "enabled_channels": ["email"],
            "poll_interval_seconds": "30",
            "cpu_threshold": "90",
            "memory_threshold": "90",
            "smtp_host": "smtp.example.com",
            "smtp_port": "587",
            "smtp_username": "me@example.com",
            "smtp_password": "first-secret",
            "smtp_from_addr": "",
            "smtp_to_addr": "",
        },
    )
    client.post(
        "/settings/notifications",
        data={
            "enabled_channels": ["email"],
            "poll_interval_seconds": "30",
            "cpu_threshold": "90",
            "memory_threshold": "90",
            "smtp_host": "smtp.example.com",
            "smtp_port": "587",
            "smtp_username": "me@example.com",
            "smtp_password": "",
            "smtp_from_addr": "",
            "smtp_to_addr": "",
        },
    )

    from platformctl.web import notify

    assert notify.load_notify_config()["smtp"]["password"] == "first-secret"


def test_notifications_stream_requires_auth(client):
    response = client.get("/notifications/stream", follow_redirects=False)
    assert response.status_code == 303


def test_logout_revokes_the_session_not_just_the_cookie(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    stolen_session_cookie = client.cookies["platformctl_session"]

    client.get("/logout", follow_redirects=False)

    # A copy of the cookie taken before logout must not still work afterwards -
    # this is what makes logout an actual revocation, not just "the browser
    # forgot it". delete_cookie() already cleared the client's own jar, so
    # re-set it to simulate someone replaying a copy they captured earlier.
    client.cookies.set("platformctl_session", stolen_session_cookie)
    response = client.get("/", follow_redirects=False)
    assert response.status_code == 303


def test_sign_out_everywhere_revokes_all_sessions(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    response = client.post("/settings/revoke-all", follow_redirects=False)
    assert response.status_code == 303
    assert response.headers["location"] == "/login"

    after = client.get("/", follow_redirects=False)
    assert after.status_code == 303


def test_audit_requires_auth(client):
    response = client.get("/audit", follow_redirects=False)
    assert response.status_code == 303


def test_command_run_is_recorded_in_audit_log(client, enrolled, totp_code):
    _login(client, enrolled, totp_code)
    with client.stream("GET", "/run/validate") as response:
        list(response.iter_text())  # drain the stream so the command actually finishes

    page = client.get("/audit")
    assert page.status_code == 200
    assert "validate" in page.text
    assert "./setup" in page.text
