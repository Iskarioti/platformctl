#!/usr/bin/env bash
set -euo pipefail

# Installs the Dev Container CLI via mise-managed Node, so governed projects
# (policy/development.json requireDevContainer) work immediately after native
# Linux/macOS bootstrap, matching what wsl/install-devcontainers-cli.sh already
# provides for the Windows-hosted WSL engineering plane.

if command -v devcontainer >/dev/null 2>&1; then
  echo "devcontainer CLI already installed: $(devcontainer --version)"
  exit 0
fi

if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
fi

export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"

if ! grep -qF 'mise activate bash' "$HOME/.bashrc" 2>/dev/null; then
  echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
fi

if [[ "$(uname -s)" == "Darwin" ]] && [[ -f "$HOME/.zshrc" ]]; then
  if ! grep -qF 'mise activate zsh' "$HOME/.zshrc" 2>/dev/null; then
    echo 'eval "$(~/.local/bin/mise activate zsh)"' >> "$HOME/.zshrc"
  fi
fi

mise use --global node@lts
npm install -g @devcontainers/cli

devcontainer --version
