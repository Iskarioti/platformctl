#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
  Linux)
    systemctl --user disable --now workstation-autosync.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/workstation-autosync.service" \
          "$HOME/.config/systemd/user/workstation-autosync.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    ;;
  Darwin)
    PLIST="$HOME/Library/LaunchAgents/com.workstation.autosync.plist"
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    ;;
esac
