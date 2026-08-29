from __future__ import annotations

import base64
import hashlib
import hmac
import json
import secrets
import time
from dataclasses import dataclass

import pyotp

from .config import CREDENTIALS_FILE, SESSION_SECRET_FILE, secure_write

SESSION_TTL_SECONDS = 12 * 60 * 60  # 12 hours
SCRYPT_N = 2**14
SCRYPT_R = 8
SCRYPT_P = 1


@dataclass
class Credentials:
    username: str
    password_salt: bytes
    password_hash: bytes
    totp_secret: str


def is_enrolled() -> bool:
    return CREDENTIALS_FILE.exists()


def _hash_password(password: str, salt: bytes) -> bytes:
    return hashlib.scrypt(
        password.encode("utf-8"),
        salt=salt,
        n=SCRYPT_N,
        r=SCRYPT_R,
        p=SCRYPT_P,
        dklen=32,
    )


def enroll(username: str, password: str) -> str:
    """Create the single local operator account. Returns the generated TOTP secret."""
    salt = secrets.token_bytes(16)
    password_hash = _hash_password(password, salt)
    totp_secret = pyotp.random_base32()

    secure_write(
        CREDENTIALS_FILE,
        json.dumps(
            {
                "username": username,
                "password_salt_hex": salt.hex(),
                "password_hash_hex": password_hash.hex(),
                "totp_secret": totp_secret,
            }
        ),
    )
    return totp_secret


def load_credentials() -> Credentials | None:
    if not CREDENTIALS_FILE.exists():
        return None
    data = json.loads(CREDENTIALS_FILE.read_text(encoding="utf-8"))
    return Credentials(
        username=data["username"],
        password_salt=bytes.fromhex(data["password_salt_hex"]),
        password_hash=bytes.fromhex(data["password_hash_hex"]),
        totp_secret=data["totp_secret"],
    )


def verify_password(creds: Credentials, password: str) -> bool:
    candidate = _hash_password(password, creds.password_salt)
    return hmac.compare_digest(candidate, creds.password_hash)


def verify_totp(creds: Credentials, code: str) -> bool:
    code = code.strip()
    if not code:
        return False
    return pyotp.TOTP(creds.totp_secret).verify(code, valid_window=1)


def totp_provisioning_uri(username: str, totp_secret: str) -> str:
    return pyotp.TOTP(totp_secret).provisioning_uri(name=username, issuer_name="platformctl")


# --- Session tokens: stateless, HMAC-signed, carry a per-session CSRF value ---


def _session_secret() -> bytes:
    if not SESSION_SECRET_FILE.exists():
        secure_write(SESSION_SECRET_FILE, secrets.token_hex(32))
    return bytes.fromhex(SESSION_SECRET_FILE.read_text(encoding="utf-8").strip())


def create_session_token(username: str) -> str:
    expires = int(time.time()) + SESSION_TTL_SECONDS
    csrf = secrets.token_hex(16)
    payload = f"{username}|{expires}|{csrf}"
    payload_b64 = base64.urlsafe_b64encode(payload.encode("utf-8")).decode("ascii")
    signature = hmac.new(_session_secret(), payload_b64.encode("ascii"), hashlib.sha256).hexdigest()
    return f"{payload_b64}.{signature}"


@dataclass
class Session:
    username: str
    csrf: str


def verify_session_token(token: str | None) -> Session | None:
    if not token or "." not in token:
        return None
    payload_b64, _, signature = token.partition(".")
    expected = hmac.new(_session_secret(), payload_b64.encode("ascii"), hashlib.sha256).hexdigest()
    if not hmac.compare_digest(expected, signature):
        return None
    try:
        payload = base64.urlsafe_b64decode(payload_b64.encode("ascii")).decode("utf-8")
        username, expires_str, csrf = payload.split("|", 2)
        expires = int(expires_str)
    except (ValueError, UnicodeDecodeError):
        return None
    if time.time() > expires:
        return None
    return Session(username=username, csrf=csrf)


# --- Login attempt backoff (in-memory, single-process; resets on restart) ---

_failed_attempts: dict[str, list[float]] = {}
_WINDOW_SECONDS = 15 * 60
_MAX_ATTEMPTS_BEFORE_BACKOFF = 5


def backoff_seconds_remaining(key: str) -> float:
    now = time.time()
    attempts = [t for t in _failed_attempts.get(key, []) if now - t < _WINDOW_SECONDS]
    _failed_attempts[key] = attempts
    if len(attempts) < _MAX_ATTEMPTS_BEFORE_BACKOFF:
        return 0.0
    excess = len(attempts) - _MAX_ATTEMPTS_BEFORE_BACKOFF
    delay = min(2**excess, 300)  # cap at 5 minutes
    elapsed = now - attempts[-1]
    remaining = delay - elapsed
    return max(0.0, remaining)


def record_failed_attempt(key: str) -> None:
    _failed_attempts.setdefault(key, []).append(time.time())


def clear_failed_attempts(key: str) -> None:
    _failed_attempts.pop(key, None)
