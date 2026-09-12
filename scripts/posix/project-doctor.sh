#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$ROOT/scripts/posix/resolve-project.sh"
TARGET="$(resolve_project_target "$ROOT" "${1:-$PWD}")" || exit 2

"$ROOT/scripts/posix/project-check.sh" "$TARGET"
status=$?

echo
echo "=== Project Doctor ==="
echo "Path: $TARGET"
echo "Filesystem: $(df -T "$TARGET" 2>/dev/null | awk 'NR==2 {print $2}' || true)"
echo "Branch: $(git -C "$TARGET" branch --show-current 2>/dev/null || echo n/a)"
echo "Git: $(git --version 2>/dev/null || echo missing)"
echo "Docker: $(docker --version 2>/dev/null || echo missing)"
echo "Code: $(code --version 2>/dev/null | head -n1 || echo missing)"
echo "Python: $(python3 --version 2>/dev/null || echo missing)"
echo "Node: $(node --version 2>/dev/null || echo missing)"
echo "Terraform: $(terraform version 2>/dev/null | head -n1 || echo missing)"

python3 - "$ROOT" "$TARGET" <<'PY'
import json, sys, datetime
from pathlib import Path

root = Path(sys.argv[1]); target = Path(sys.argv[2])
meta_path = target / ".platformctl" / "project.json"
if not meta_path.exists():
    sys.exit(0)

meta = json.loads(meta_path.read_text(encoding="utf-8"))
template = meta.get("template")
project_version = meta.get("templateVersion", "0.0.0")

catalog_path = root / "templates" / "catalog.json"
if catalog_path.exists() and template:
    catalog = json.loads(catalog_path.read_text(encoding="utf-8")).get("templates", {})
    entry = catalog.get(template)
    if entry:
        current_version = entry.get("version", "0.0.0")
        status = entry.get("status", "active")
        if status == "deprecated":
            print(f"WARN  Template '{template}' is deprecated - see templates/catalog.json")
        elif current_version != project_version:
            print(f"WARN  Template '{template}' has moved on: this project was created from "
                  f"v{project_version}, current is v{current_version} - review what changed.")
        else:
            print(f"PASS  Template '{template}' v{project_version} (current)")

scan_path = target / ".platformctl" / "security-scan.json"
if scan_path.exists():
    scan = json.loads(scan_path.read_text(encoding="utf-8"))
    scanned_at = datetime.datetime.fromisoformat(scan["scannedAtUtc"])
    age_days = (datetime.datetime.now(datetime.timezone.utc) - scanned_at).days
    findings = scan.get("findingsCount", "?")
    state = "PASS" if age_days <= 14 else "WARN"
    print(f"{state}  Last security scan: {age_days}d ago, {findings} tool(s) reported findings "
          f"(workstation security scan .)")
else:
    print("WARN  Never security-scanned - run: workstation security scan .")
PY

exit "$status"
