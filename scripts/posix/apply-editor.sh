#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/editor/editor.env"

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
WORKSTATION_CONFIG="$CONFIG_HOME/workstation"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$CONFIG_HOME" "$WORKSTATION_CONFIG" "$BIN_DIR"

timestamp="$(date +%Y%m%d-%H%M%S)"

deploy_profile() {
  local src="$1"
  local dst="$2"

  mkdir -p "$dst"

  # Dedicated NVIM_APPNAME directories are wholly managed by platformctl.
  # Preserve a one-time backup before taking ownership of an unmanaged profile.
  if [[ -d "$dst" && ! -f "$dst/.platformctl-managed" ]]; then
    if find "$dst" -mindepth 1 -maxdepth 1 | read -r _; then
      cp -a "$dst" "${dst}.backup.${timestamp}"
      echo "BACKUP    ${dst}.backup.${timestamp}"
    fi
  fi

  rm -rf "$dst"
  mkdir -p "$dst"
  cp -a "$src/." "$dst/"
  touch "$dst/.platformctl-managed"
  echo "COPIED    $dst"
}

deploy_profile "$ROOT/editor/neovim/platform" "$CONFIG_HOME/nvim-platform"
deploy_profile "$ROOT/editor/neovim/minimal" "$CONFIG_HOME/nvim-minimal"
deploy_profile "$ROOT/editor/neovim/nvchad" "$CONFIG_HOME/nvim-nvchad"

# Traditional Vim is intentionally a single rescue configuration.
if [[ -f "$HOME/.vimrc" ]] && ! cmp -s "$ROOT/editor/vim/vimrc" "$HOME/.vimrc"; then
  cp -f "$HOME/.vimrc" "$HOME/.vimrc.backup.$timestamp"
fi
cp -f "$ROOT/editor/vim/vimrc" "$HOME/.vimrc"

if [[ ! -f "$WORKSTATION_CONFIG/editor-profile" ]]; then
  printf '%s\n' "$DEFAULT_NVIM_PROFILE" > "$WORKSTATION_CONFIG/editor-profile"
fi

cat > "$BIN_DIR/nvim" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROFILE_FILE="$HOME/.config/workstation/editor-profile"
PROFILE="platform"

[[ -f "$PROFILE_FILE" ]] && PROFILE="$(tr -d '[:space:]' < "$PROFILE_FILE")"

case "$PROFILE" in
  platform) APP="nvim-platform" ;;
  nvchad)   APP="nvim-nvchad" ;;
  minimal)  APP="nvim-minimal" ;;
  *)
    echo "Unknown Neovim profile '$PROFILE'; falling back to platform." >&2
    APP="nvim-platform"
    ;;
esac

NVIM_APPNAME="$APP" exec "$HOME/.local/bin/nvim-real" "$@"
EOF
chmod +x "$BIN_DIR/nvim"

cat > "$BIN_DIR/nvim-platform" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
NVIM_APPNAME=nvim-platform exec "$HOME/.local/bin/nvim-real" "$@"
EOF

cat > "$BIN_DIR/nvim-chad" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
NVIM_APPNAME=nvim-nvchad exec "$HOME/.local/bin/nvim-real" "$@"
EOF

cat > "$BIN_DIR/nvim-minimal" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
NVIM_APPNAME=nvim-minimal exec "$HOME/.local/bin/nvim-real" "$@"
EOF

chmod +x \
  "$BIN_DIR/nvim-platform" \
  "$BIN_DIR/nvim-chad" \
  "$BIN_DIR/nvim-minimal"

echo "Editor configuration applied using cp only."
