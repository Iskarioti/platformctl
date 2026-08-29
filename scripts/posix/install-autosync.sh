#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

case "$(uname -s)" in
  Linux)
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    WORKSTATION_CONFIG_DIR="$HOME/.config/workstation"
    BIN_DIR="$HOME/.local/bin"

    SERVICE="$SYSTEMD_USER_DIR/workstation-autosync.service"
    TIMER="$SYSTEMD_USER_DIR/workstation-autosync.timer"
    RUNNER="$BIN_DIR/workstation-autosync-run"

    mkdir -p "$SYSTEMD_USER_DIR" "$WORKSTATION_CONFIG_DIR" "$BIN_DIR"

    # Keep the systemd unit itself independent of repository paths containing
    # spaces (for example a Windows OneDrive mount under /mnt/c).
    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      "ROOT=$(printf '%q' "$ROOT")" \
      'exec "$ROOT/scripts/common/autosync.sh" --once' \
      > "$RUNNER"

    chmod +x "$RUNNER"

    cat > "$SERVICE" <<'EOF'
[Unit]
Description=platformctl workstation autosync

[Service]
Type=oneshot
ExecStart=%h/.local/bin/workstation-autosync-run
Nice=10
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
      echo "ERROR: the systemd user manager is unavailable." >&2
      echo "On WSL, verify /etc/wsl.conf contains:" >&2
      echo "  [boot]" >&2
      echo "  systemd=true" >&2
      exit 4
    fi

    systemctl --user daemon-reload

    echo "Verifying autosync units..."
    systemd-analyze --user verify "$SERVICE" "$TIMER"

    systemctl --user reset-failed workstation-autosync.service \
      workstation-autosync.timer 2>/dev/null || true

    systemctl --user enable workstation-autosync.timer >/dev/null
    systemctl --user start workstation-autosync.timer

    if ! systemctl --user is-active --quiet workstation-autosync.timer; then
      echo "ERROR: workstation-autosync.timer did not become active." >&2
      systemctl --user --no-pager -l status workstation-autosync.timer >&2 || true
      systemctl --user --no-pager -l status workstation-autosync.service >&2 || true
      exit 5
    fi

    echo
    echo "platformctl autosync timer enabled."
    echo "Repository: $ROOT"
    systemctl --user --no-pager -l status workstation-autosync.timer
    ;;

  Darwin)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.config/workstation"

    PLIST="$HOME/Library/LaunchAgents/com.workstation.autosync.plist"

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
