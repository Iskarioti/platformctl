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
  templates) jq -r '.projects.allowedTemplates[]' "$ROOT/policy/development.json" ;;
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
