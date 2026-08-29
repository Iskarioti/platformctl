#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/editor/editor.env"

PROFILE_FILE="$HOME/.config/workstation/editor-profile"

usage() {
  cat <<'EOF'
workstation editor commands:

  install                 install pinned Neovim and apply profiles
  apply                   deploy managed editor configuration
  doctor                  inspect editor health
  list                    list available profiles
  profile [name]          show or select platform|nvchad|minimal
  sync [profile]          install/update plugins for a profile
  clean                   launch Neovim with --clean
EOF
}

editor_list() {
  current="$DEFAULT_NVIM_PROFILE"
  [[ -f "$PROFILE_FILE" ]] && current="$(tr -d '[:space:]' < "$PROFILE_FILE")"

  printf '%-10s %-9s %s\n' "PROFILE" "DEFAULT" "PURPOSE"
  printf '%-10s %-9s %s\n' "platform" "$([[ "$current" == platform ]] && echo yes || echo no)" "LazyVim platform engineering IDE"
  printf '%-10s %-9s %s\n' "nvchad" "$([[ "$current" == nvchad ]] && echo yes || echo no)" "NvChad alternate interface"
  printf '%-10s %-9s %s\n' "minimal" "$([[ "$current" == minimal ]] && echo yes || echo no)" "Plugin-free Neovim repair profile"
  printf '%-10s %-9s %s\n' "vim" "-" "Plugin-free rescue editor"
}

editor_profile() {
  local requested="${1:-}"

  if [[ -z "$requested" ]]; then
    if [[ -f "$PROFILE_FILE" ]]; then
      cat "$PROFILE_FILE"
    else
      echo "$DEFAULT_NVIM_PROFILE"
    fi
    return
  fi

  case "$requested" in
    platform|nvchad|minimal) ;;
    *)
      echo "ERROR: profile must be platform, nvchad or minimal." >&2
      exit 2
      ;;
  esac

  mkdir -p "$(dirname "$PROFILE_FILE")"
  printf '%s\n' "$requested" > "$PROFILE_FILE"
  echo "Default Neovim profile: $requested"
}

doctor_line() {
  local state="$1"
  local name="$2"
  local detail="${3:-}"
  printf '%-5s %-20s %s\n' "$state" "$name" "$detail"
}

editor_doctor() {
  echo "=== Editor Doctor ==="

  if command -v nvim-real >/dev/null 2>&1; then
    version="$(nvim-real --version | head -n1)"
    doctor_line PASS "Neovim" "$version"
  else
    doctor_line MISS "Neovim" "run: workstation editor install"
  fi

  for cmd in git rg fzf make gcc; do
    if command -v "$cmd" >/dev/null 2>&1; then
      doctor_line PASS "$cmd" "$(command -v "$cmd")"
    else
      doctor_line WARN "$cmd" "recommended"
    fi
  done

  if command -v fd >/dev/null 2>&1 || command -v fdfind >/dev/null 2>&1; then
    doctor_line PASS "fd" "available"
  else
    doctor_line WARN "fd" "recommended"
  fi

  if command -v lazygit >/dev/null 2>&1; then
    doctor_line PASS "lazygit" "$(lazygit --version 2>/dev/null | head -n1)"
  else
    doctor_line WARN "lazygit" "optional"
  fi

  if command -v tree-sitter >/dev/null 2>&1; then
    doctor_line PASS "tree-sitter" "$(tree-sitter --version 2>/dev/null | head -n1)"
  else
    doctor_line WARN "tree-sitter-cli" "LazyVim Treesitter parser builds may require it"
  fi

  for dir in nvim-platform nvim-nvchad nvim-minimal; do
    if [[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/$dir/.platformctl-managed" ]]; then
      doctor_line PASS "$dir" "managed"
    else
      doctor_line MISS "$dir" "run: workstation editor apply"
    fi
  done

  doctor_line INFO "default profile" "$(editor_profile)"
}

editor_sync() {
  local profile="${1:-$(editor_profile)}"

  case "$profile" in
    platform)
      echo "Synchronizing LazyVim platform profile..."
      NVIM_APPNAME=nvim-platform "$HOME/.local/bin/nvim-real" \
        --headless "+Lazy! sync" +qa
      ;;
    nvchad)
      echo "Synchronizing NvChad profile..."
      NVIM_APPNAME=nvim-nvchad "$HOME/.local/bin/nvim-real" \
        --headless "+Lazy! sync" +qa
      ;;
    minimal)
      echo "Minimal profile has no plugins."
      ;;
    *)
      echo "ERROR: sync profile must be platform, nvchad or minimal." >&2
      exit 2
      ;;
  esac
}

cmd="${1:-help}"
shift || true

case "$cmd" in
  install)
    "$ROOT/scripts/posix/install-neovim.sh"
    "$ROOT/scripts/posix/apply-editor.sh"
    editor_doctor
    ;;
  apply)
    "$ROOT/scripts/posix/apply-editor.sh"
    ;;
  doctor)
    editor_doctor
    ;;
  list)
    editor_list
    ;;
  profile)
    editor_profile "${1:-}"
    ;;
  sync)
    editor_sync "${1:-}"
    ;;
  clean)
    exec "$HOME/.local/bin/nvim-real" --clean "$@"
    ;;
  help|-h|--help)
    usage
    ;;
  *)
    echo "Unknown editor command: $cmd" >&2
    usage >&2
    exit 2
    ;;
esac
