#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$(uname -s)" in
  Darwin) TARGET_DIR="$HOME/Library/Application Support/Code/User" ;;
  Linux)  TARGET_DIR="$HOME/.config/Code/User" ;;
  *) exit 0 ;;
esac

mkdir -p "$TARGET_DIR"
TARGET="$TARGET_DIR/settings.json"
if [[ -f "$TARGET" ]]; then
  cp -f "$TARGET" "$TARGET.backup.$(date +%Y%m%d-%H%M%S)"
fi
cp -f "$ROOT/vscode/settings.json" "$TARGET"

if command -v code >/dev/null 2>&1; then
  while IFS= read -r extension; do
    [[ -z "$extension" ]] && continue
    code --install-extension "$extension" --force >/dev/null || true
  done < "$ROOT/vscode/extensions.txt"
fi
