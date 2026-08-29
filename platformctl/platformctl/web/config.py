from __future__ import annotations

import os
import stat
from pathlib import Path

CONFIG_DIR = Path(os.environ.get("PLATFORMCTL_CONTROL_PLANE_DIR", "")) if os.environ.get(
    "PLATFORMCTL_CONTROL_PLANE_DIR"
) else Path.home() / ".config" / "workstation" / "control-plane"

CREDENTIALS_FILE = CONFIG_DIR / "credentials.json"
SESSION_SECRET_FILE = CONFIG_DIR / "session_secret"
NOTIFY_CONFIG_FILE = CONFIG_DIR / "notify.json"


def ensure_config_dir() -> Path:
    CONFIG_DIR.mkdir(parents=True, exist_ok=True)
    try:
        os.chmod(CONFIG_DIR, stat.S_IRWXU)  # 0700
    except OSError:
        pass
    return CONFIG_DIR


def secure_write(path: Path, content: str) -> None:
    """Write a secret-bearing file with 0600 permissions, never world/group readable."""
    ensure_config_dir()
    fd = os.open(str(path), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        f.write(content)
