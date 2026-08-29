#!/usr/bin/env bash
set -euo pipefail

ROOT="${1:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"
ROOT="$(cd "$ROOT" && pwd)"

required=(
  "$ROOT/setup"
  "$ROOT/setup.ps1"
  "$ROOT/scripts/posix/workstation.sh"
  "$ROOT/scripts/posix/editor.sh"
  "$ROOT/editor/editor.env"
)

for f in "${required[@]}"; do
  if [[ ! -f "$f" ]]; then
    echo "ERROR: required editor-management file missing: $f" >&2
    echo "Reapply the v3.3.0 editor-management overlay first." >&2
    exit 2
  fi
done

STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="$ROOT/.state/editor-dispatch-repair-$STAMP"
mkdir -p "$BACKUP/scripts/posix"

cp -f "$ROOT/setup" "$BACKUP/setup"
cp -f "$ROOT/setup.ps1" "$BACKUP/setup.ps1"
cp -f "$ROOT/scripts/posix/workstation.sh" "$BACKUP/scripts/posix/workstation.sh"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import sys

root = Path(sys.argv[1])

setup = root / "setup"
text = setup.read_text(encoding="utf-8")

old = "validate|doctor|enforce|project|services|sync|publish|autosync|update|dry-run|help)"
new = "validate|doctor|enforce|project|services|editor|sync|publish|autosync|update|dry-run|help)"

if new not in text:
    if old not in text:
        raise SystemExit("ERROR: could not locate command-dispatch list in setup")
    text = text.replace(old, new, 1)

setup.write_text(text, encoding="utf-8")

ws = root / "scripts/posix/workstation.sh"
text = ws.read_text(encoding="utf-8")

editor_case = '  editor) exec "$ROOT/scripts/posix/editor.sh" "$@" ;;'

if editor_case not in text:
    anchor = '  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;'
    if anchor not in text:
        raise SystemExit("ERROR: could not locate services dispatcher in workstation.sh")
    text = text.replace(anchor, anchor + "\n" + editor_case, 1)

help_anchor = "  services reset <service> [--yes]\n"
help_line = "  editor install|apply|doctor|list|profile|sync|clean\n"

if help_line not in text:
    if help_anchor not in text:
        raise SystemExit("ERROR: could not locate help insertion point in workstation.sh")
    text = text.replace(help_anchor, help_anchor + help_line, 1)

ws.write_text(text, encoding="utf-8")

ps1 = root / "setup.ps1"
text = ps1.read_text(encoding="utf-8")

editor_block = '''    "editor" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation "$@"' workstation editor @Rest
            exit $LASTEXITCODE
        } else {
            & bash (Join-Path $Root "scripts/posix/editor.sh") @Rest
            exit $LASTEXITCODE
        }
    }

'''

if '"editor" {' not in text:
    anchor = '    "sync"     {'
    if anchor not in text:
        raise SystemExit("ERROR: could not locate sync dispatcher in setup.ps1")
    text = text.replace(anchor, editor_block + anchor, 1)

help_anchor = "  services down                     stop catalog containers, preserve data\n"
help_line = "  editor install|apply|doctor       manage Neovim/NvChad/Vim editor profiles\n"

if help_line not in text:
    if help_anchor not in text:
        raise SystemExit("ERROR: could not locate help insertion point in setup.ps1")
    text = text.replace(help_anchor, help_anchor + help_line, 1)

ps1.write_text(text, encoding="utf-8")
PY

chmod +x "$ROOT/setup" "$ROOT/scripts/posix/workstation.sh" "$ROOT/scripts/posix/editor.sh"

echo "Validating Bash syntax..."
bash -n "$ROOT/setup"
bash -n "$ROOT/scripts/posix/workstation.sh"
bash -n "$ROOT/scripts/posix/editor.sh"

echo
echo "Editor dispatcher repaired."
echo "Backups: $BACKUP"
echo
echo "Verify with:"
echo "  workstation editor list"
echo "  workstation editor doctor"
echo
echo "Then install:"
echo "  workstation editor install"
