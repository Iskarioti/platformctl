#!/usr/bin/env bash
set -euo pipefail

# Runs "platformctl serve" as a persistent background service (not a periodic
# timer like autosync/autoupgrade) - always up, restarted if it dies, started
# automatically at login. platformctl serve itself still binds 127.0.0.1
# only; this just controls whether it's always running vs. run by hand.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PORT="${1:-8765}"

PLATFORMCTL_BIN="$(command -v platformctl || true)"
if [[ -z "$PLATFORMCTL_BIN" ]]; then
  echo "ERROR: platformctl is not installed (run platformctl/bootstrap.sh first)." >&2
  exit 2
fi

case "$(uname -s)" in
  Linux)
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SYSTEMD_USER_DIR"

    SERVICE="$SYSTEMD_USER_DIR/workstation-dashboard.service"

    cat > "$SERVICE" <<EOF
[Unit]
Description=platformctl web control plane (workstation dashboard)
After=network.target

[Service]
Type=simple
ExecStart=$PLATFORMCTL_BIN serve --port $PORT
Restart=on-failure
RestartSec=5
Nice=10

[Install]
WantedBy=default.target
EOF

    if ! command -v systemctl >/dev/null 2>&1; then
      echo "ERROR: systemctl is unavailable; the dashboard service was not enabled." >&2
      exit 3
    fi

    if ! systemctl --user show-environment >/dev/null 2>&1; then
      echo "ERROR: the systemd user manager is unavailable." >&2
      echo "On WSL, verify /etc/wsl.conf contains:" >&2
      echo "  [boot]" >&2
      echo "  systemd=true" >&2
      exit 4
    fi

    systemctl --user daemon-reload

    echo "Verifying dashboard service unit..."
    systemd-analyze --user verify "$SERVICE"

    systemctl --user reset-failed workstation-dashboard.service 2>/dev/null || true
    systemctl --user enable workstation-dashboard.service >/dev/null
    systemctl --user restart workstation-dashboard.service

    sleep 1
    if ! systemctl --user is-active --quiet workstation-dashboard.service; then
      echo "ERROR: workstation-dashboard.service did not become active." >&2
      systemctl --user --no-pager -l status workstation-dashboard.service >&2 || true
      exit 5
    fi

    echo
    echo "Dashboard service enabled: http://127.0.0.1:$PORT (always on, restarts on failure)."
    systemctl --user --no-pager -l status workstation-dashboard.service
    ;;

  Darwin)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.config/workstation"
    PLIST="$HOME/Library/LaunchAgents/com.workstation.dashboard.plist"

    xml_escape() {
      printf '%s' "$1" |
        sed \
          -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
    }

    BIN_XML="$(xml_escape "$PLATFORMCTL_BIN")"
    HOME_XML="$(xml_escape "$HOME")"

    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.workstation.dashboard</string>

  <key>ProgramArguments</key>
  <array>
    <string>${BIN_XML}</string>
    <string>serve</string>
    <string>--port</string>
    <string>${PORT}</string>
  </array>

  <key>RunAtLoad</key>
  <true/>

  <key>KeepAlive</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${HOME_XML}/.config/workstation/dashboard.log</string>

  <key>StandardErrorPath</key>
  <string>${HOME_XML}/.config/workstation/dashboard.err.log</string>
</dict>
</plist>
EOF

    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"

    echo "Dashboard LaunchAgent enabled: http://127.0.0.1:$PORT (always on, restarts on failure)."
    ;;

  *)
    echo "ERROR: unsupported platform: $(uname -s)" >&2
    exit 2
    ;;
esac
