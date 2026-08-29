#!/usr/bin/env bash
set -euo pipefail

REPO="${1:-}"
[[ -n "$REPO" ]] || {
  echo "Usage: $0 /path/to/platformctl" >&2
  exit 2
}

REPO="$(cd "$REPO" && pwd)"
PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OVERLAY="$PKG/overlay"
BACKUP="$REPO/.state/editor-upgrade-backup-$(date +%Y%m%d-%H%M%S)"

mkdir -p "$BACKUP"

copy_one() {
  local src="$1"
  local rel="${src#$OVERLAY/}"
  local dst="$REPO/$rel"

  mkdir -p "$(dirname "$dst")"

  if [[ -f "$dst" ]]; then
    mkdir -p "$BACKUP/$(dirname "$rel")"
    cp -f "$dst" "$BACKUP/$rel"
  fi

  cp -f "$src" "$dst"
  echo "COPIED $rel"
}

while IFS= read -r -d '' f; do
  copy_one "$f"
done < <(find "$OVERLAY" -type f -print0)

echo
echo "Files copied."
echo "For dispatcher/bootstrap patching on the Windows-managed platformctl repository,"
echo "run apply-to-platformctl.ps1 from PowerShell."
