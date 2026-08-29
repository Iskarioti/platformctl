#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

command -v jq >/dev/null 2>&1 || { echo "jq is required to read workstation.json." >&2; exit 2; }

ENABLED="$(jq -r '.autoUpdate.enabled // false' "$ROOT/workstation.json")"
if [[ "$ENABLED" != "true" ]]; then
  echo "autoUpdate.enabled is false in workstation.json; autoupgrade timer not installed."
  exit 0
fi

WINDOW_START="$(jq -r '.autoUpdate.schedule.windowStart // "22:00"' "$ROOT/workstation.json")"
HOUR="${WINDOW_START%%:*}"
MINUTE="${WINDOW_START##*:}"

case "$(uname -s)" in
  Linux)
    SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
    WORKSTATION_CONFIG_DIR="$HOME/.config/workstation"
    BIN_DIR="$HOME/.local/bin"

    SERVICE="$SYSTEMD_USER_DIR/workstation-autoupgrade.service"
    TIMER="$SYSTEMD_USER_DIR/workstation-autoupgrade.timer"
    RUNNER="$BIN_DIR/workstation-autoupgrade-run"

    mkdir -p "$SYSTEMD_USER_DIR" "$WORKSTATION_CONFIG_DIR" "$BIN_DIR"

    printf '%s\n' \
      '#!/usr/bin/env bash' \
      'set -euo pipefail' \
      "ROOT=$(printf '%q' "$ROOT")" \
      'exec "$ROOT/scripts/posix/upgrade.sh" --unattended' \
      > "$RUNNER"

    chmod +x "$RUNNER"

    cat > "$SERVICE" <<EOF
[Unit]
Description=platformctl workstation component upgrade

[Service]
Type=oneshot
ExecStart=%h/.local/bin/workstation-autoupgrade-run
Nice=15
EOF

    cat > "$TIMER" <<EOF
[Unit]
Description=Run platformctl workstation component upgrade daily

[Timer]
OnCalendar=*-*-* $(printf '%02d' "$((10#$HOUR))"):$(printf '%02d' "$((10#$MINUTE))"):00
Persistent=true
Unit=workstation-autoupgrade.service

[Install]
WantedBy=timers.target
EOF

    if ! command -v systemctl >/dev/null 2>&1; then
      echo "ERROR: systemctl is unavailable; autoupgrade was not enabled." >&2
      exit 3
    fi

    if ! systemctl --user show-environment >/dev/null 2>&1; then
      echo "ERROR: the systemd user manager is unavailable." >&2
      exit 4
    fi

    systemctl --user daemon-reload
    systemctl --user reset-failed workstation-autoupgrade.service \
      workstation-autoupgrade.timer 2>/dev/null || true
    systemctl --user enable workstation-autoupgrade.timer >/dev/null
    systemctl --user start workstation-autoupgrade.timer

    echo "platformctl autoupgrade timer enabled (daily at $WINDOW_START)."
    echo "Note: the 'packages' scope uses sudo; configure passwordless sudo for"
    echo "the specific apt/dnf/pacman upgrade commands if you want it to run"
    echo "unattended, or rely on 'workstation upgrade --scope=packages' manually."
    ;;

  Darwin)
    mkdir -p "$HOME/Library/LaunchAgents" "$HOME/.config/workstation"
    PLIST="$HOME/Library/LaunchAgents/com.workstation.autoupgrade.plist"

    cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.workstation.autoupgrade</string>

  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/env</string>
    <string>bash</string>
    <string>${ROOT}/scripts/posix/upgrade.sh</string>
    <string>--unattended</string>
  </array>

  <key>WorkingDirectory</key>
  <string>${ROOT}</string>

  <key>StartCalendarInterval</key>
  <dict>
    <key>Hour</key>
    <integer>$((10#$HOUR))</integer>
    <key>Minute</key>
    <integer>$((10#$MINUTE))</integer>
  </dict>

  <key>StandardOutPath</key>
  <string>${HOME}/.config/workstation/autoupgrade.log</string>

  <key>StandardErrorPath</key>
  <string>${HOME}/.config/workstation/autoupgrade.err.log</string>
</dict>
</plist>
EOF

    launchctl bootout "gui/$(id -u)" "$PLIST" 2>/dev/null || true
    launchctl bootstrap "gui/$(id -u)" "$PLIST"

    echo "platformctl autoupgrade LaunchAgent enabled (daily at $WINDOW_START)."
    ;;

  *)
    echo "ERROR: unsupported platform: $(uname -s)" >&2
    exit 2
    ;;
esac
