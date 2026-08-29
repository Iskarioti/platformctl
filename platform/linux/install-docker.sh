#!/usr/bin/env bash
set -euo pipefail

if command -v docker >/dev/null 2>&1; then
  exit 0
fi

TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
curl -fsSL https://get.docker.com -o "$TMP"
sudo sh "$TMP"
sudo usermod -aG docker "$USER" || true

echo "Docker installed. A new login may be required for docker-group membership."
