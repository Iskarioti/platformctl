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

copy_managed "$ROOT/shell/oh-my-posh/tokyonight-architect.omp.json" \
  "$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"

copy_managed "$ROOT/vscode/settings.json" \
  "$HOME/.config/workstation/vscode-settings.json"

case "$(uname -s)" in
  Linux)
    copy_managed "$ROOT/shell/bash/architect.bashrc" "$HOME/.config/workstation/architect.bashrc"
    if ! grep -Fq '# >>> workstation-managed >>>' "$HOME/.bashrc" 2>/dev/null; then
      cat >> "$HOME/.bashrc" <<'EOF'

# >>> workstation-managed >>>
[[ -f "$HOME/.config/workstation/architect.bashrc" ]] && source "$HOME/.config/workstation/architect.bashrc"
# <<< workstation-managed <<<
EOF
    fi
    ;;
  Darwin)
    copy_managed "$ROOT/shell/zsh/architect.zshrc" "$HOME/.config/workstation/architect.zshrc"
    if ! grep -Fq '# >>> workstation-managed >>>' "$HOME/.zshrc" 2>/dev/null; then
      cat >> "$HOME/.zshrc" <<'EOF'

# >>> workstation-managed >>>
[[ -f "$HOME/.config/workstation/architect.zshrc" ]] && source "$HOME/.config/workstation/architect.zshrc"
# <<< workstation-managed <<<
EOF
    fi
    ;;
esac

[[ "$QUIET" -eq 0 ]] && echo "POSIX configuration applied using cp only."
