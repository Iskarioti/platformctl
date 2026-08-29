#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/policy/development.json"

TEMPLATE="${1:-}"
NAME="${2:-}"
if [[ $# -ge 2 ]]; then shift 2; else set --; fi

AREA="labs"
CUSTOM_ROOT=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --area) AREA="${2:-}"; shift 2 ;;
    --root) CUSTOM_ROOT="${2:-}"; shift 2 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [[ -z "$TEMPLATE" || -z "$NAME" ]]; then
  echo "Usage: workstation project init <template> <name> [--area company|platform|automation|labs|tooling]" >&2
  exit 2
fi

[[ "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
  echo "Project name contains unsupported characters: $NAME" >&2; exit 2;
}

jq -e --arg t "$TEMPLATE" '.projects.allowedTemplates | index($t) != null' "$POLICY" >/dev/null || {
  echo "Template is not allowed by policy: $TEMPLATE" >&2
  jq -r '.projects.allowedTemplates[] | "  - " + .' "$POLICY" >&2
  exit 2
}

case "$AREA" in company|platform|automation|labs|tooling) ;; *) echo "Unsupported project area: $AREA" >&2; exit 2 ;; esac

SOURCE="$ROOT/templates/projects/$TEMPLATE"
[[ -d "$SOURCE" ]] || { echo "Template source does not exist: $SOURCE" >&2; exit 2; }

if [[ -n "$CUSTOM_ROOT" ]]; then BASE="${CUSTOM_ROOT/#\~/$HOME}"; else BASE="$HOME/src/$AREA"; fi
DEST="$BASE/$NAME"

[[ ! -e "$DEST" ]] || { echo "Destination already exists: $DEST" >&2; exit 3; }

mkdir -p "$BASE" "$DEST"
cp -R "$SOURCE/." "$DEST/"

python3 - "$DEST" "$NAME" "$TEMPLATE" "$AREA" <<'PY'
from pathlib import Path
import json, sys, datetime

dest=Path(sys.argv[1]); name=sys.argv[2]; template=sys.argv[3]; area=sys.argv[4]
for p in dest.rglob("*"):
    if not p.is_file():
        continue
    try:
        text=p.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    p.write_text(text.replace("__PROJECT_NAME__", name), encoding="utf-8", newline="\n")

meta=dest/".platformctl"
meta.mkdir(exist_ok=True)
(meta/"project.json").write_text(json.dumps({
    "name":name,"template":template,"area":area,
    "policy":"platformctl-development-v1",
    "createdAtUtc":datetime.datetime.now(datetime.timezone.utc).isoformat()
},indent=2)+"\n",encoding="utf-8")
PY

git -C "$DEST" init -b main >/dev/null
git -C "$DEST" add .

echo "Created governed project:"
echo "  $DEST"
echo
"$ROOT/scripts/posix/project-check.sh" "$DEST"
echo
echo "Next:"
echo "  cd \"$DEST\""
echo "  code ."
echo "  install dependencies to generate the project lockfile"
echo "  git add -A && git commit -m 'feat: initialize project'"
