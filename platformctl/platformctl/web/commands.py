from __future__ import annotations

from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[3]

# Deliberately a fixed allowlist of complete argv sequences, not a free-text shell
# box or pass-through arguments: even localhost-only + authenticated, arbitrary
# shell exec would turn one leaked session cookie into full RCE. Every entry here
# is exactly what a human would type, nothing user-supplied is interpolated in.
COMMANDS: dict[str, tuple[list[str], str]] = {
    "validate": (["./setup", "validate"], "Validate repository"),
    "doctor": (["./setup", "doctor"], "Workstation doctor"),
    "enforce": (["./setup", "enforce"], "Development policy enforcement"),
    "upgrade": (["./setup", "upgrade"], "Upgrade installed components"),
    "services_status": (["./setup", "services", "status"], "Dev services status"),
    "services_doctor": (["./setup", "services", "doctor"], "Dev services doctor"),
    "services_up_core": (["./setup", "services", "up", "core"], "Start core dev services"),
    "services_up_observability": (
        ["./setup", "services", "up", "observability"],
        "Start observability stack",
    ),
    "services_down": (["./setup", "services", "down"], "Stop all dev services"),
    "project_templates": (["./setup", "project", "templates"], "List approved project templates"),
    "labs_status_redis_cluster": (
        ["scripts/posix/labs.sh", "status", "redis-cluster"],
        "Redis cluster lab status",
    ),
    "labs_status_kafka_kraft_3": (
        ["scripts/posix/labs.sh", "status", "kafka-kraft-3"],
        "Kafka KRaft lab status",
    ),
    "labs_status_redis_security": (
        ["scripts/posix/labs.sh", "status", "redis-security"],
        "Redis security lab status",
    ),
}
