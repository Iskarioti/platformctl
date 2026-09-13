#!/usr/bin/env bash
set -euo pipefail

# GitHub CLI - present on Windows (windows/10-install-tools.ps1) and macOS
# (platform/macos/bootstrap.sh's brew list) but was missing entirely from the
# Linux/WSL side (confirmed live, 2026-09-13: `gh` not installed, no install
# script existed for it) - a real cross-platform parity gap, not a deliberate
# exclusion. Not in Ubuntu/Debian's default repos, so needs GitHub's own apt
# repo added first, same shape as install-librewolf.sh's extrepo/repo-file
# dance for Debian/Fedora; Arch and Fedora both carry it directly.

if command -v gh >/dev/null 2>&1; then
  exit 0
fi

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y curl gpg
  sudo mkdir -p -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg |
    sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" |
    sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y gh
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y gh
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --needed --noconfirm github-cli
else
  echo "GitHub CLI was not installed: no supported package manager (apt, dnf, pacman) found." >&2
fi
