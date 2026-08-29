#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091
source "$ROOT/editor/editor.env"

BIN_DIR="$HOME/.local/bin"
OPT_DIR="$HOME/.local/opt"
NVIM_ROOT="$OPT_DIR/neovim-$NEOVIM_VERSION"

mkdir -p "$BIN_DIR" "$OPT_DIR"

case "$(uname -m)" in
  x86_64|amd64)
    NVIM_ARCHIVE="nvim-linux-x86_64.tar.gz"
    NVIM_FOLDER="nvim-linux-x86_64"
    LAZYGIT_ARCH="x86_64"
    ;;
  aarch64|arm64)
    NVIM_ARCHIVE="nvim-linux-arm64.tar.gz"
    NVIM_FOLDER="nvim-linux-arm64"
    LAZYGIT_ARCH="arm64"
    ;;
  *)
    echo "ERROR: Unsupported architecture: $(uname -m)" >&2
    exit 2
    ;;
esac

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command not found: $1" >&2
    exit 3
  }
}

need curl
need tar
need git

if [[ ! -x "$NVIM_ROOT/bin/nvim" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  url="https://github.com/neovim/neovim/releases/download/v${NEOVIM_VERSION}/${NVIM_ARCHIVE}"

  echo "Installing Neovim $NEOVIM_VERSION..."
  curl --fail --location --retry 3 --connect-timeout 20 \
    "$url" \
    --output "$tmp/$NVIM_ARCHIVE"

  tar -xzf "$tmp/$NVIM_ARCHIVE" -C "$tmp"

  rm -rf "$NVIM_ROOT"
  mkdir -p "$NVIM_ROOT"
  cp -a "$tmp/$NVIM_FOLDER/." "$NVIM_ROOT/"
else
  echo "Neovim $NEOVIM_VERSION already installed."
fi

# Keep the real executable distinct from the profile-selecting nvim wrapper.
ln -sfn "$NVIM_ROOT/bin/nvim" "$BIN_DIR/nvim-real"

# Optional but highly useful Git UI for the primary LazyVim profile.
if ! command -v lazygit >/dev/null 2>&1; then
  tmp_lg="$(mktemp -d)"
  lg_url="https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_linux_${LAZYGIT_ARCH}.tar.gz"

  echo "Installing lazygit $LAZYGIT_VERSION..."
  if curl --fail --location --retry 3 --connect-timeout 20 \
      "$lg_url" \
      --output "$tmp_lg/lazygit.tar.gz"; then
    tar -xzf "$tmp_lg/lazygit.tar.gz" -C "$tmp_lg" lazygit
    cp -f "$tmp_lg/lazygit" "$BIN_DIR/lazygit"
    chmod +x "$BIN_DIR/lazygit"
  else
    echo "WARNING: lazygit download failed; Neovim remains usable." >&2
  fi
  rm -rf "$tmp_lg"
fi

echo "Neovim binary installation complete."
