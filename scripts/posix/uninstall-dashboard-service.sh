#!/usr/bin/env bash
set -euo pipefail
case "$(uname -s)" in
  Linux)
    systemctl --user disable --now workstation-dashboard.service 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/workstation-dashboard.service"
    systemctl --user daemon-reload 2>/dev/null || true
    ;;
  Darwin)
    PLIST="$HOME/Library/LaunchAgents/com.workstation.dashboard.plist"
    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    rm -f "$PLIST"
    ;;
esac
echo "Dashboard background service disabled."
