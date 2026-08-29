#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$(uname -s)" in
  Linux)
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    WORKSTATION_STATE_DIR="$HOME/.config/workstation"

    mkdir -p "$SYSTEMD_USER_DIR" "$WORKSTATION_STATE_DIR"

    SERVICE="$SYSTEMD_USER_DIR/workstation-autosync.service"
    TIMER="$SYSTEMD_USER_DIR/workstation-autosync.timer"

    cat > "$SERVICE" <<EOF
[Unit]
Description=platformctl workstation autosync
Documentation=file://$ROOT/docs/autosync.md
After=default.target

[Service]
Type=oneshot
WorkingDirectory="$ROOT"
ExecStart=/usr/bin/env bash "$ROOT/scripts/common/autosync.sh" --once
Nice=10

[Install]
WantedBy=default.target
EOF

    cat > "$TIMER" <<'EOF'
[Unit]
Description=Run platformctl workstation autosync every minute

[Timer]
OnBootSec=60
OnUnitActiveSec=60
AccuracySec=10
Persistent=true
Unit=workstation-autosync.service

[Install]
WantedBy=timers.target
EOF

    if ! command -v systemctl >/dev/null 2>&1; then
      echo "ERROR: systemctl is unavailable; autosync was not enabled." >&2
      exit 3
    fi

    if ! systemctl --user show-environment >/dev/null 2>&1; then
      echo "ERROR: the systemd user manager is unavailable in this Linux/WSL session." >&2
      echo "Verify /etc/wsl.conf contains:" >&2
      echo "  [boot]" >&2
      echo "  systemd=true" >&2
      exit 4
    fi

    systemctl --user daemon-reload
    systemctl --user enable --now workstation-autosync.timer

    echo
    echo "platformctl autosync timer enabled."
    echo "Repository: $ROOT"
    systemctl --user --no-pager status workstation-autosync.timer || true
    ;;

  Darwin)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.config/workstation"

    PLIST="$HOME/Library/LaunchAgents/com.workstation.autosync.plist"

    # XML-escape paths before embedding them in the plist.
    xml_escape() {
      printf '%s' "$1" |
        sed \
          -e 's/&/\&amp;/g' \
          -e 's/</\&lt;/g' \
          -e 's/>/\&gt;/g' \
          -e 's/"/\&quot;/g' \
          -e "s/'/\&apos;/g"
    }

    ROOT_XML="$(xml_escape "$ROOT")"
    HOME_XML="$(xml_escape "$HOME")"

    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.workstation.autosync</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>bash</string>
    <string>${ROOT_XML}/scripts/common/autosync.sh</string>
    <string>--once</string>
  </array>

  <key>WorkingDirectory</key>
  <string>${ROOT_XML}</string>

  <key>StartInterval</key>
  <integer>60</integer>

  <key>RunAtLoad</key>
  <true/>

  <key>StandardOutPath</key>
  <string>${HOME_XML}/.config/workstation/autosync.log</string>

  <key>StandardErrorPath</key>
  <string>${HOME_XML}/.config/workstation/autosync.err.log</string>
</dict>
</plist>
EOF

    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"

    echo "platformctl autosync LaunchAgent enabled."
    ;;

  *)
    echo "ERROR: unsupported platform: $(uname -s)" >&2
    exit 2
    ;;
esac
