#!/usr/bin/env bash
set -euo pipefail

# Install Node through mise to avoid polluting system package state with a fixed distro version.
curl https://mise.run | sh
echo 'eval "$(~/.local/bin/mise activate bash)"' >> "$HOME/.bashrc"
export PATH="$HOME/.local/bin:$PATH"
eval "$(mise activate bash)"

mise use --global node@lts
npm install -g @devcontainers/cli

devcontainer --version
