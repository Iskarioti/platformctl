#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTION="${1:-help}"
shift || true

case "$ACTION" in
  init) exec "$ROOT/scripts/posix/project-init.sh" "$@" ;;
  adopt) exec "$ROOT/scripts/posix/project-adopt.sh" "$@" ;;
  check) exec "$ROOT/scripts/posix/project-check.sh" "$@" ;;
  doctor) exec "$ROOT/scripts/posix/project-doctor.sh" "$@" ;;
  open) exec "$ROOT/scripts/posix/project-open.sh" "$@" ;;
  templates)
    python3 - "$ROOT" <<'PY'
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
names = json.loads((root / "policy/development.json").read_text())["projects"]["allowedTemplates"]

for name in names:
    readme = root / "templates/projects" / name / "README.md"
    desc = ""
    if readme.exists():
        lines = readme.read_text(encoding="utf-8").splitlines()
        # Skip the "# __PROJECT_NAME__" heading and blank lines, then take
        # the first paragraph (until the next blank line or heading).
        body = [l for l in lines[1:]]
        para = []
        started = False
        for line in body:
            if not line.strip():
                if started:
                    break
                continue
            if line.startswith("#"):
                break
            started = True
            para.append(line.strip())
        desc = " ".join(para)
    print(f"{name:<20} {desc}")
PY
    ;;
  *)
    cat <<'EOF'
workstation project commands:
  project templates
  project init <template> <name> [--area company|platform|automation|labs|tooling]
  project adopt [path|name]   register an existing/cloned project (.platformctl/project.json only - nothing else is touched)
  project check [path|name]
  project doctor [path|name]
  project open [path|name]

[path|name]: a real path, OR a bare project name (e.g. "wiocchub-api") resolved
by searching policy/development.json's projectRoots - defaults to $PWD if omitted.
EOF
    ;;
esac
