#!/usr/bin/env bash
set -euo pipefail

# CLI/headless - unlike Wireshark/Solaar above, WireGuard needs no display, so
# this isn't gated on GUI availability the way the alacritty/librewolf/wireshark
# installs are. Modern kernels (5.6+) have the WireGuard module built in, so only
# the userspace tools (wg, wg-quick) need installing on any current distro/WSL.

if command -v wg >/dev/null 2>&1; then
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireguard
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y wireguard-tools
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --needed --noconfirm wireguard-tools
else
  echo "WireGuard was not installed: no supported package manager (apt, dnf, pacman) found." >&2
fi
