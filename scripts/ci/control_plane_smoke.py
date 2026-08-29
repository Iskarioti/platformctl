#!/usr/bin/env python3
"""
Real end-to-end smoke test for the platformctl control plane, driven over HTTP
against an already-running `platformctl serve` instance.

Not just for CI: run this by hand against a real instance any time you want to
confirm the login/session/command-runner path still works without doing it by
hand with curl.

Usage:
    PLATFORMCTL_CONTROL_PLANE_DIR=/tmp/some-throwaway-dir platformctl serve --port 8765 &
    python3 scripts/ci/control_plane_smoke.py --port 8765
"""
from __future__ import annotations

import argparse
import re
import sys

import httpx
import pyotp


def fail(message: str) -> None:
    print(f"FAIL: {message}", file=sys.stderr)
    sys.exit(1)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=8765)
    args = parser.parse_args()
    base = f"http://127.0.0.1:{args.port}"

    with httpx.Client(base_url=base, timeout=10) as client:
        r = client.get("/", follow_redirects=False)
        if r.status_code != 303 or r.headers.get("location") != "/login":
            fail(f"expected unauthenticated / to redirect to /login, got {r.status_code}")
        print("PASS unauthenticated redirect")

        r = client.post(
            "/setup",
            data={
                "username": "ci-smoke",
                "password": "correct-horse-battery-staple",
                "confirm_password": "correct-horse-battery-staple",
            },
        )
        match = re.search(r'<code class="secret">([A-Z0-9]+)</code>', r.text)
        if not match:
            fail("could not extract TOTP secret from /setup response")
        totp_secret = match.group(1)
        print("PASS enrollment")

        code = pyotp.TOTP(totp_secret).now()
        r = client.post(
            "/login",
            data={"username": "ci-smoke", "password": "wrong-password", "totp_code": code},
        )
        if "Invalid username" not in r.text:
            fail("wrong password was not rejected")
        print("PASS wrong password rejected")

        r = client.post(
            "/login",
            data={"username": "ci-smoke", "password": "correct-horse-battery-staple", "totp_code": code},
            follow_redirects=False,
        )
        if r.status_code != 303 or "platformctl_session" not in r.cookies:
            fail(f"login did not succeed, got {r.status_code}")
        print("PASS login")

        r = client.get("/")
        if r.status_code != 200 or "ci-smoke" not in r.text:
            fail("authenticated / did not render the logged-in dashboard")
        print("PASS authenticated dashboard")

        for path in (
            "/panels/services",
            "/panels/ai-runtime",
            "/panels/labs",
            "/panels/projects",
            "/panels/jobs",
            "/panels/resources",
        ):
            r = client.get(path)
            if r.status_code != 200:
                fail(f"{path} returned {r.status_code}")
        print("PASS all status panels render")

        with client.stream("GET", "/run/validate") as r:
            body = "".join(r.iter_text())
        if "$ ./setup validate" not in body or "event: done" not in body:
            fail("command runner did not stream the expected output")
        print("PASS command runner (SSE)")

        r = client.get("/audit")
        if r.status_code != 200 or "validate" not in r.text:
            fail("the command just run did not show up in the audit log")
        print("PASS audit log records commands")

        stolen_cookie = client.cookies.get("platformctl_session")
        r = client.get("/logout", follow_redirects=False)
        if r.status_code != 303:
            fail("logout did not redirect")
        r = client.get("/", follow_redirects=False)
        if r.status_code != 303:
            fail("session was not actually cleared by logout")
        client.cookies.set("platformctl_session", stolen_cookie)
        r = client.get("/", follow_redirects=False)
        if r.status_code != 303:
            fail("a session cookie captured before logout still worked afterwards - "
                 "logout is not actually revoking the session")
        print("PASS logout revokes the session, not just the cookie")

    print("ALL PASS")


if __name__ == "__main__":
    main()
