#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.local/bin"
if ! command -v oh-my-posh >/dev/null 2>&1; then
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
fi
