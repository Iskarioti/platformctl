#!/usr/bin/env bash
set -euo pipefail

if command -v librewolf >/dev/null 2>&1; then
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y extrepo
  sudo extrepo enable librewolf
  sudo extrepo update librewolf
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y librewolf
elif command -v dnf >/dev/null 2>&1; then
  if ! sudo dnf config-manager --add-repo https://repo.librewolf.net/librewolf.repo 2>/dev/null; then
    sudo dnf config-manager addrepo --from-repofile=https://repo.librewolf.net/librewolf.repo
  fi
  sudo dnf install -y librewolf
elif command -v pacman >/dev/null 2>&1; then
  # Official Arch "extra" repository already carries librewolf - no third-party
  # repo/keyring setup needed, unlike Debian (extrepo) and Fedora (repo file).
  sudo pacman -Sy --needed --noconfirm librewolf
else
  echo "LibreWolf was not installed: no supported package manager (apt, dnf, pacman) found." >&2
fi
