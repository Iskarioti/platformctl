#!/usr/bin/env bash
set -euo pipefail

FONT_DIR="$HOME/.local/share/fonts"
mkdir -p "$FONT_DIR/JetBrainsMono" "$FONT_DIR/JetBrainsMonoNerd"

# Official JetBrains Mono installer maintained by JetBrains.
curl -fsSL https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/install_manual.sh | bash

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
curl -fL https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip \
  -o "$TMP/JetBrainsMonoNerd.zip"
unzip -oq "$TMP/JetBrainsMonoNerd.zip" -d "$FONT_DIR/JetBrainsMonoNerd"

command -v fc-cache >/dev/null 2>&1 && fc-cache -f
echo "JetBrains Mono + JetBrainsMono Nerd Font installed."
