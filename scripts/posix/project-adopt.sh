#!/usr/bin/env bash
set -euo pipefail

# Registers an EXISTING directory (a pre-existing project, or one just
# "git clone"'d) as a governed project by writing .platformctl/project.json -
# the one thing "workstation project check"/the dashboard's governed-projects
# panel key off of to know a project exists at all.
#
# Unlike project-init.sh (which scaffolds a brand-new project from a
# template), adopt never touches any other file: a pre-existing/cloned
# codebase keeps its own structure, scaffolding, and conventions, managed
# independently by the project itself. It never runs "git init" either - the
# repo already exists, with its own history/remote.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/policy/development.json"

command -v jq >/dev/null 2>&1 || { echo "jq is required." >&2; exit 2; }

source "$ROOT/scripts/posix/resolve-project.sh"
TARGET="$(resolve_project_target "$ROOT" "${1:-$PWD}")" || exit 2

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Existing git repository detected - left untouched (no git init, no auto-commit)."
else
  echo "WARNING: $TARGET is not a git repository yet. Registering anyway; policy still" >&2
  echo "requires one (run 'git init' yourself when ready)." >&2
fi

NAME="$(basename "$TARGET")"

# Area is derived from where it already lives, not asked for - adopt doesn't
# relocate anything.
area="unknown"
while IFS= read -r configured; do
  expanded="${configured/#\~/$HOME}"
  case "$TARGET/" in
    "$expanded"/*/)
      area="$(basename "$expanded")"
      break
      ;;
  esac
done < <(jq -r '.projectRoots[]' "$POLICY")

if [[ -f "$TARGET/.platformctl/project.json" ]]; then
  echo "Already registered: $TARGET/.platformctl/project.json exists - left untouched."
else
  mkdir -p "$TARGET/.platformctl"
  python3 - "$TARGET" "$NAME" "$area" <<'PY'
from pathlib import Path
import json, sys, datetime

dest = Path(sys.argv[1]); name = sys.argv[2]; area = sys.argv[3]
(dest / ".platformctl" / "project.json").write_text(json.dumps({
    "name": name,
    "template": None,
    "area": area,
    "policy": "platformctl-development-v1",
    "developmentServices": [],
    "adopted": True,
    "adoptedAtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
}, indent=2) + "\n", encoding="utf-8")
PY
  echo "Registered governed project: $TARGET/.platformctl/project.json"
fi

echo ""
echo "Nothing else was changed - the project's own structure, scaffolding, and"
echo "conventions are left as-is, managed independently."
echo ""
"$ROOT/scripts/posix/project-check.sh" "$TARGET"
