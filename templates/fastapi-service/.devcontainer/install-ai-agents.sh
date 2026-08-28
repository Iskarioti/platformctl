#!/usr/bin/env bash
set -euo pipefail

if [[ "${INSTALL_AI_AGENTS:-1}" != "1" ]]; then
  echo "AI agent installation disabled."
  exit 0
fi

export PATH="$HOME/.local/bin:$HOME/.codex/bin:$PATH"

if ! command -v codex >/dev/null 2>&1; then
  echo "Installing Codex CLI..."
  curl -fsSL https://chatgpt.com/codex/install.sh | sh
fi

if ! command -v claude >/dev/null 2>&1; then
  echo "Installing Claude Code..."
  curl -fsSL https://claude.ai/install.sh | bash
fi

echo "Codex:"
command -v codex >/dev/null 2>&1 && codex --version || echo "Restart terminal if installer updated PATH."
echo "Claude:"
command -v claude >/dev/null 2>&1 && claude --version || echo "Restart terminal if installer updated PATH."
