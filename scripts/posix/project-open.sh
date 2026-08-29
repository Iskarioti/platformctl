#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-$PWD}"

"$ROOT/scripts/posix/project-check.sh" "$TARGET"

command -v code >/dev/null 2>&1 || {
  echo "VS Code 'code' command is not available in this shell." >&2
  exit 4
}

cd "$TARGET"
exec code .
