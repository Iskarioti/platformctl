#!/usr/bin/env bash
set -euo pipefail

# Systems & Platform Architect - managed macOS Dock/Finder/appearance
# defaults. Values reused from Andrew's previous nix-darwin
# system.defaults block (github.com/Iskarioti/.dotfiles, nix/darwin/
# flake.nix) - ported here as plain `defaults write` calls since this repo
# is imperative bash/PowerShell, not Nix.
#
# Idempotent: every `defaults write` / dockutil call converges to the same
# end state on re-run, even though dockutil's own operation (remove all,
# re-add in order) is not itself a no-op each time.

# Terminal.app's canonical path moved under /System/Applications on newer
# macOS - check both since this script cannot be tested on real hardware
# from this session (Windows-only environment).
terminal_app="/System/Applications/Utilities/Terminal.app"
[[ -e "$terminal_app" ]] || terminal_app="/Applications/Utilities/Terminal.app"

DOCK_APPS=(
  "/System/Library/CoreServices/Finder.app"
  "/Applications/LibreWolf.app"
  "/Applications/Visual Studio Code.app"
  "$terminal_app"
  "/System/Applications/Mail.app"
  "/System/Applications/Calendar.app"
)

# --- Dock ---
defaults write com.apple.dock tilesize -int 32
defaults write com.apple.dock largesize -int 100
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock magnification -bool true
defaults write com.apple.dock mineffect -string genie
defaults write com.apple.dock show-recents -bool false

if command -v dockutil >/dev/null 2>&1; then
  dockutil --remove all --no-restart >/dev/null 2>&1 || true
  for app in "${DOCK_APPS[@]}"; do
    if [[ -e "$app" ]]; then
      dockutil --add "$app" --no-restart >/dev/null 2>&1 || \
        echo "WARNING: dockutil could not pin: $app" >&2
    else
      echo "NOTE: not installed, skipped pinning: $app" >&2
    fi
  done
else
  echo "WARNING: dockutil not found - Dock app pinning skipped (run 'brew install dockutil')." >&2
fi

# --- Finder / global appearance ---
defaults write com.apple.finder FXPreferredViewStyle -string clmv
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write NSGlobalDomain AppleInterfaceStyle -string Dark
defaults write NSGlobalDomain AppleICUForce24HourTime -bool true
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write com.apple.screencapture location -string "$HOME/Downloads"

# Hardening, not just cosmetic: guest login stays disabled.
defaults write /Library/Preferences/com.apple.loginwindow GuestEnabled -bool false 2>/dev/null || \
  echo "NOTE: disabling GuestEnabled needs sudo - run this script with sudo to apply that one setting." >&2

# --- Apply ---
killall Dock >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo "macOS Dock/Finder/appearance defaults applied."
