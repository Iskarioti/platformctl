#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
  Linux)
    systemctl --user disable --now workstation-autoupgrade.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/workstation-autoupgrade.service" \
          "$HOME/.config/systemd/user/workstation-autoupgrade.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    ;;
  Darwin)
    PLIST="$HOME/Library/LaunchAgents/com.workstation.autoupgrade.plist"
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    ;;
esac
