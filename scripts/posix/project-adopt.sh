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

TARGET_ARG=""
AREA_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --area) AREA_OVERRIDE="${2:-}"; shift 2 ;;
    *)
      if [[ -n "$TARGET_ARG" ]]; then
        echo "Unknown argument: $1" >&2
        echo "Usage: workstation project adopt [path|name] [--area $(valid_project_areas "$ROOT" | tr ' ' '|')]" >&2
        exit 2
      fi
      TARGET_ARG="$1"
      shift
      ;;
  esac
done

if [[ -n "$AREA_OVERRIDE" ]]; then
  is_valid_project_area "$ROOT" "$AREA_OVERRIDE" || {
    echo "Unsupported project area: $AREA_OVERRIDE" >&2
    echo "Valid areas (from policy/development.json's projectRoots): $(valid_project_areas "$ROOT")" >&2
    exit 2
  }
fi

TARGET="$(resolve_project_target "$ROOT" "${TARGET_ARG:-$PWD}")" || exit 2

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Existing git repository detected - left untouched (no git init, no auto-commit)."
else
  echo "WARNING: $TARGET is not a git repository yet. Registering anyway; policy still" >&2
  echo "requires one (run 'git init' yourself when ready)." >&2
fi

NAME="$(basename "$TARGET")"

# --area lets you declare the area explicitly - needed when the project
# doesn't already live under one of policy/development.json's projectRoots
# (adopt never relocates anything, so there'd otherwise be nothing to infer
# from) or when you want it filed under a different area than wherever it
# happens to sit today. Without --area, fall back to inferring it from
# whichever configured root the path is actually under, same as before -
# "unknown" only if neither was available.
area="${AREA_OVERRIDE:-unknown}"
if [[ -z "$AREA_OVERRIDE" ]]; then
  while IFS= read -r configured; do
    expanded="${configured/#\~/$HOME}"
    case "$TARGET/" in
      "$expanded"/*/)
        area="$(basename "$expanded")"
        break
        ;;
    esac
  done < <(jq -r '.projectRoots[]' "$POLICY")
fi

if [[ -f "$TARGET/.platformctl/project.json" ]]; then
  if [[ -n "$AREA_OVERRIDE" ]]; then
    # Already-registered projects can still have their area corrected - a
    # project adopted before this flag existed (or simply filed under the
    # wrong area) shouldn't require hand-editing project.json. Every other
    # field (template, developmentServices, adoptedAtUtc, ...) is preserved.
    python3 - "$TARGET" "$area" <<'PY'
from pathlib import Path
import json, sys

dest = Path(sys.argv[1]); area = sys.argv[2]
meta_path = dest / ".platformctl" / "project.json"
meta = json.loads(meta_path.read_text(encoding="utf-8"))
meta["area"] = area
meta_path.write_text(json.dumps(meta, indent=2) + "\n", encoding="utf-8")
PY
    echo "Already registered: $TARGET/.platformctl/project.json - updated area to '$area'."
  else
    echo "Already registered: $TARGET/.platformctl/project.json exists - left untouched."
    echo "(pass --area to update it, e.g. --area company)"
  fi
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
