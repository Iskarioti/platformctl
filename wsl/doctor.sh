#!/usr/bin/env bash
set -uo pipefail

pass() { printf "%-28s PASS  %s\n" "$1" "${2:-}"; }
fail() { printf "%-28s FAIL  %s\n" "$1" "${2:-}"; }

command -v git >/dev/null && pass "git" "$(git --version)" || fail "git"
command -v docker >/dev/null && docker info >/dev/null 2>&1 \
  && pass "docker" "$(docker --version)" || fail "docker"
docker compose version >/dev/null 2>&1 \
  && pass "docker compose" "$(docker compose version --short)" || fail "docker compose"
command -v ssh >/dev/null && pass "ssh" || fail "ssh"
command -v curl >/dev/null && pass "curl" || fail "curl"
command -v jq >/dev/null && pass "jq" || fail "jq"
command -v az >/dev/null && pass "azure cli" "$(az version --query '"azure-cli"' -o tsv 2>/dev/null)" || fail "azure cli"
command -v code >/dev/null && pass "VS Code bridge" || fail "VS Code bridge"
command -v devcontainer >/dev/null && pass "devcontainer CLI" "$(devcontainer --version)" || fail "devcontainer CLI"

printf "\nDisk:\n"
df -h "$HOME" | tail -n 1
printf "\nMemory:\n"
free -h
printf "\nDocker usage:\n"
docker system df 2>/dev/null || true
