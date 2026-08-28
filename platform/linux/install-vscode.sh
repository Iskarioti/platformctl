#!/usr/bin/env bash
set -euo pipefail

if command -v code >/dev/null 2>&1; then
  exit 0
fi

if command -v snap >/dev/null 2>&1; then
  sudo snap install code --classic
elif command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  flatpak install -y flathub com.visualstudio.code
else
  echo "VS Code was not installed: neither snap nor flatpak is available." >&2
fi
