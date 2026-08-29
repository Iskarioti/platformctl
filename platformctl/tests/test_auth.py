from __future__ import annotations

import time

import pyotp

from platformctl.web import auth


def test_not_enrolled_by_default(isolated_config):
    assert auth.is_enrolled() is False


def test_enroll_then_load(isolated_config):
    secret = auth.enroll("andrew", "correct-horse-battery-staple")
    assert auth.is_enrolled() is True

    creds = auth.load_credentials()
    assert creds is not None
    assert creds.username == "andrew"
    assert creds.totp_secret == secret
    # The raw password must never be recoverable from what's stored on disk.
    assert "correct-horse-battery-staple" not in creds.password_hash.hex()


def test_verify_password_correct_and_incorrect(enrolled):
    creds = auth.load_credentials()
    assert auth.verify_password(creds, enrolled["password"]) is True
    assert auth.verify_password(creds, "wrong password entirely") is False


def test_verify_totp_correct_and_incorrect(enrolled, totp_code):
    creds = auth.load_credentials()
    assert auth.verify_totp(creds, totp_code) is True
    assert auth.verify_totp(creds, "000000") is False
    assert auth.verify_totp(creds, "") is False


def test_totp_provisioning_uri_contains_issuer(enrolled):
    uri = auth.totp_provisioning_uri(enrolled["username"], enrolled["totp_secret"])
    assert "platformctl" in uri
    assert enrolled["username"] in uri


def test_session_token_round_trip(isolated_config):
    token = auth.create_session_token("andrew")
    session = auth.verify_session_token(token)
    assert session is not None
    assert session.username == "andrew"
    assert len(session.csrf) > 0


def test_session_token_rejects_tampering(isolated_config):
    token = auth.create_session_token("andrew")
    payload, _, signature = token.partition(".")
    tampered = f"{payload}.{'0' * len(signature)}"
    assert auth.verify_session_token(tampered) is None


def test_session_token_rejects_garbage():
    assert auth.verify_session_token(None) is None
    assert auth.verify_session_token("") is None
    assert auth.verify_session_token("not-a-real-token") is None


def test_session_token_expires(isolated_config, monkeypatch):
    monkeypatch.setattr(auth, "SESSION_TTL_SECONDS", 1)
    token = auth.create_session_token("andrew")
    assert auth.verify_session_token(token) is not None
    real_now = time.time()
    monkeypatch.setattr(time, "time", lambda: real_now + 5)
    assert auth.verify_session_token(token) is None


def test_backoff_engages_after_repeated_failures(isolated_config):
    key = "test-client"
    for _ in range(5):
        assert auth.backoff_seconds_remaining(key) == 0.0
        auth.record_failed_attempt(key)
    # The 6th failure should now be backed off.
    assert auth.backoff_seconds_remaining(key) > 0.0


def test_revoke_session_invalidates_only_that_session(isolated_config):
    token_a = auth.create_session_token("andrew")
    token_b = auth.create_session_token("andrew")
    session_a = auth.verify_session_token(token_a)

    auth.revoke_session(session_a.session_id)

    assert auth.verify_session_token(token_a) is None
    assert auth.verify_session_token(token_b) is not None


def test_revoke_all_sessions_invalidates_everything(isolated_config):
    token_a = auth.create_session_token("andrew")
    token_b = auth.create_session_token("andrew")

    auth.revoke_all_sessions()

    assert auth.verify_session_token(token_a) is None
    assert auth.verify_session_token(token_b) is None


def test_backoff_clears(isolated_config):
    key = "test-client-2"
    for _ in range(6):
        auth.record_failed_attempt(key)
    assert auth.backoff_seconds_remaining(key) > 0.0
    auth.clear_failed_attempts(key)
    assert auth.backoff_seconds_remaining(key) == 0.0
