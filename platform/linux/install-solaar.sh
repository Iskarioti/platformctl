#!/usr/bin/env bash
set -euo pipefail

# Logitech does not ship an official Linux client - Logi Options+ (installed on
# Windows/macOS, see windows/10-install-tools.ps1 / platform/macos/bootstrap.sh) has
# no Linux equivalent. Solaar is the community-standard replacement for managing
# Logitech mice/keyboards (battery status, DPI, button remapping) on Linux - a
# different app, not a port of Options+, but the closest match to the same need.

if command -v solaar >/dev/null 2>&1; then
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y solaar
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y solaar
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --needed --noconfirm solaar
else
  echo "Solaar was not installed: no supported package manager (apt, dnf, pacman) found." >&2
fi
