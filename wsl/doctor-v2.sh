#!/usr/bin/env bash
set -uo pipefail

printf "=== Workstation v2 ===\n"
printf "WSL memory:\n"; free -h
printf "\nDocker:\n"; docker version --format '{{.Server.Version}}' 2>/dev/null || echo "Docker unavailable"
printf "\nCompose:\n"; docker compose version 2>/dev/null || true
printf "\nAI network:\n"; docker network inspect ai-runtime --format '{{.Name}}' 2>/dev/null || echo "ai-runtime network missing"
printf "\nAI state:\n"
for d in "$HOME/.codex" "$HOME/.claude"; do
  [[ -d "$d" ]] && ls -ld "$d" || echo "Missing $d"
done
printf "\nTools:\n"
for c in git ssh az task trivy platformctl; do
  command -v "$c" >/dev/null && printf "%-14s %s\n" "$c" "$(command -v "$c")" || printf "%-14s MISSING\n" "$c"
done
