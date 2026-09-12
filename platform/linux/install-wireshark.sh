#!/usr/bin/env bash
set -euo pipefail

# GUI network analyzer - matches Wireshark on Windows/macOS. Only useful with a
# display (native Linux desktop, or WSLg on Windows 11's WSL) - same caveat as
# alacritty/librewolf on this platform, not an error if there's no display.
# Package managers default to requiring sudo/the wireshark group for live capture
# (no setuid dumpcap) under a non-interactive install - that's the safer default
# and this script does not override it (AGENTS.md rule 3: don't loosen security
# posture to make automation smoother). Run `sudo usermod -aG wireshark $USER`
# yourself afterward if you want capture without sudo.

if command -v wireshark >/dev/null 2>&1; then
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y wireshark
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y wireshark
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --needed --noconfirm wireshark-qt
else
  echo "Wireshark was not installed: no supported package manager (apt, dnf, pacman) found." >&2
fi
