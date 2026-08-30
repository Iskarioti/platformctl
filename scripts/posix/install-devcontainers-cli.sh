#!/usr/bin/env bash
set -euo pipefail

# Installs the Dev Container CLI via mise-managed Node, so governed projects
# (policy/development.json requireDevContainer) work immediately after native
# Linux/macOS bootstrap or WSL bootstrap (called from both
# platform/linux/bootstrap.sh, platform/macos/bootstrap.sh, and
# wsl/bootstrap.sh).
#
# Two lessons learned the hard way on a real Windows+WSL machine this
# session, both from the same root cause (don't trust bare PATH resolution):
#
# 1. On WSL, "command -v devcontainer" can find a completely unrelated
#    Windows-native @devcontainers/cli install (e.g. one VS Code's Dev
#    Containers extension installed on its own) via WSL's Windows-PATH
#    interop. That binary can never find "docker" (Docker only exists inside
#    WSL per this repo's policy) and fails every time. So the idempotency
#    check below explicitly rejects any hit under /mnt/*.
# 2. mise's shims only land on PATH for interactive/login shells (via
#    ".bashrc"'s "mise activate"). Any script invoked non-interactively -
#    which is how this repo's own project-open.sh/etc. run - would silently
#    fall through to that same wrong Windows binary. So this always
#    symlinks the real one into ~/.local/bin, which is reliably on PATH
#    everywhere in this repo (it's where the "workstation" command itself
#    lives).

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

if [[ -x "$BIN_DIR/devcontainer" ]] && "$BIN_DIR/devcontainer" --version >/dev/null 2>&1; then
  echo "devcontainer CLI already installed: $("$BIN_DIR/devcontainer" --version)"
  exit 0
fi

if ! command -v mise >/dev/null 2>&1; then
  curl https://mise.run | sh
fi

export PATH="$BIN_DIR:$PATH"
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

# "mise which" only resolves mise-registered tool versions, not arbitrary
# packages installed via "npm install -g" under a mise-managed Node - ask
# npm directly for its own global prefix instead of guessing/trusting PATH.
NPM_PREFIX="$(npm prefix -g)"
ln -sf "$NPM_PREFIX/bin/devcontainer" "$BIN_DIR/devcontainer"

echo "Linked $BIN_DIR/devcontainer -> $NPM_PREFIX/bin/devcontainer"
"$BIN_DIR/devcontainer" --version
