#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
QUIET=0
[[ "${1:-}" == "--quiet" ]] && QUIET=1

copy_managed() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"

  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    [[ "$QUIET" -eq 0 ]] && echo "UNCHANGED $dst"
    return 0
  fi

  if [[ -f "$dst" ]]; then
    cp -f "$dst" "$dst.backup.$(date +%Y%m%d-%H%M%S)"
  fi

  cp -f "$src" "$dst"
  [[ "$QUIET" -eq 0 ]] && echo "COPIED    $dst"
}

ensure_source_block() {
  local rcfile="$1"
  local managed="$2"
  mkdir -p "$(dirname "$rcfile")"
  touch "$rcfile"
  if ! grep -Fq '# >>> workstation-managed >>>' "$rcfile" 2>/dev/null; then
    cat >> "$rcfile" <<EOF2

# >>> workstation-managed >>>
[[ -f "$managed" ]] && source "$managed"
# <<< workstation-managed <<<
EOF2
  fi
}

copy_managed "$ROOT/shell/oh-my-posh/tokyonight-architect.omp.json" "$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"
copy_managed "$ROOT/vscode/settings.json" "$HOME/.config/workstation/vscode-settings.json"

case "$(uname -s)" in
  Linux)
    copy_managed "$ROOT/shell/bash/architect.bashrc" "$HOME/.config/workstation/architect.bashrc"
    copy_managed "$ROOT/shell/zsh/architect.zshrc" "$HOME/.config/workstation/architect.zshrc"
    ensure_source_block "$HOME/.bashrc" '$HOME/.config/workstation/architect.bashrc'
    if [[ -f "$HOME/.zshrc" ]] || command -v zsh >/dev/null 2>&1; then
      ensure_source_block "$HOME/.zshrc" '$HOME/.config/workstation/architect.zshrc'
    fi
    ;;
  Darwin)
    copy_managed "$ROOT/shell/zsh/architect.zshrc" "$HOME/.config/workstation/architect.zshrc"
    ensure_source_block "$HOME/.zshrc" '$HOME/.config/workstation/architect.zshrc'
    ;;
esac

[[ "$QUIET" -eq 0 ]] && echo "POSIX configuration applied using cp only."
