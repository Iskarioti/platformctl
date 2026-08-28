#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$(uname -s)" in
  Linux)
    mkdir -p "$HOME/.config/systemd/user"
    cat > "$HOME/.config/systemd/user/workstation-autosync.service" <<EOF
[Unit]
Description=Workstation setup autosync

[Service]
Type=oneshot
ExecStart=$ROOT/scripts/common/autosync.sh --once
EOF

    cat > "$HOME/.config/systemd/user/workstation-autosync.timer" <<'EOF'
[Unit]
Description=Run workstation autosync every minute

[Timer]
OnBootSec=60
OnUnitActiveSec=60
Persistent=true

[Install]
WantedBy=timers.target
EOF

    if command -v systemctl >/dev/null 2>&1; then
      systemctl --user daemon-reload
      systemctl --user enable --now workstation-autosync.timer
    else
      echo "systemd user services unavailable; autosync not enabled automatically."
    fi
    ;;

  Darwin)
    mkdir -p "$HOME/Library/LaunchAgents"
    PLIST="$HOME/Library/LaunchAgents/com.workstation.autosync.plist"
    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.workstation.autosync</string>
  <key>ProgramArguments</key>
  <array>
    <string>$ROOT/scripts/common/autosync.sh</string>
    <string>--once</string>
  </array>
  <key>StartInterval</key><integer>60</integer>
  <key>RunAtLoad</key><true/>
  <key>StandardOutPath</key><string>$HOME/.config/workstation/autosync.log</string>
  <key>StandardErrorPath</key><string>$HOME/.config/workstation/autosync.err.log</string>
</dict>
</plist>
launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$PLIST"
    ;;
esac
