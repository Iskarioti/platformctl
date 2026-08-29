from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any

from .config import AUDIT_LOG_FILE, secure_append


def log_command(username: str, command_id: str, argv: list[str], exit_code: int | None) -> None:
    entry = {
        "ts": datetime.now(timezone.utc).isoformat(),
        "username": username,
        "command_id": command_id,
        "argv": argv,
        "exit_code": exit_code,
    }
    secure_append(AUDIT_LOG_FILE, json.dumps(entry))


def read_recent(limit: int = 100) -> list[dict[str, Any]]:
    if not AUDIT_LOG_FILE.exists():
        return []
    entries: list[dict[str, Any]] = []
    for line in AUDIT_LOG_FILE.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            entries.append(json.loads(line))
        except json.JSONDecodeError:
            continue
    return list(reversed(entries[-limit:]))
