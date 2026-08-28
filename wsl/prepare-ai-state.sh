#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.codex" "$HOME/.claude"
chmod 700 "$HOME/.codex" "$HOME/.claude"

# Shared external network used by the local model runtime and trusted Dev Containers.
docker network inspect ai-runtime >/dev/null 2>&1 || docker network create ai-runtime >/dev/null

echo "Prepared:"
echo "  $HOME/.codex"
echo "  $HOME/.claude"
echo "  Docker network: ai-runtime"
echo
echo "These directories contain sensitive agent state/credentials after login."
echo "Do not add them to Git and do not mount them into untrusted containers."
