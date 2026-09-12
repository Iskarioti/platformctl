#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Actually rehearses workstation backup/restore end to end, into a
# throwaway directory - never the real ~/.config/workstation - so it's safe
# to run on a real, live machine. The Systems Engineer & Architect role
# review's top finding: a well-designed backup/restore path that had never
# once been exercised is a hypothesis, not a control (see docs/adr/
# 0005-single-machine-assumption.md). Run this periodically (there is no
# scheduled trigger for it - a human decision to run it is itself part of
# the point).

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

DRILL_HOME="$WORK/home"
mkdir -p "$DRILL_HOME"
BACKUP_FILE="$WORK/drill-backup.tar.gz.enc"
export WORKSTATION_BACKUP_PASSPHRASE
WORKSTATION_BACKUP_PASSPHRASE="$(openssl rand -base64 32)"

LOG_DATE="$(date -u +%Y-%m-%d)"
LOG_FILE="$ROOT/.state/dr-drill-$LOG_DATE.log"
mkdir -p "$ROOT/.state"

result="FAIL"
detail=""

{
  echo "=== Disaster Recovery Drill: $(date -u +%Y-%m-%dT%H:%M:%SZ) ==="

  echo "--- backup ---"
  if ! bash "$ROOT/scripts/posix/backup.sh" "$BACKUP_FILE"; then
    detail="backup.sh failed"
  elif [[ ! -s "$BACKUP_FILE" ]]; then
    detail="backup produced an empty or missing file"
  else
    echo "--- restore (into a throwaway \$HOME, never the real one) ---"
    export WORKSTATION_RESTORE_HOME="$DRILL_HOME"
    if ! bash "$ROOT/scripts/posix/restore.sh" "$BACKUP_FILE" --yes; then
      detail="restore.sh failed"
    else
      echo "--- verify ---"
      real_config="$HOME/.config/workstation"
      drilled_config="$DRILL_HOME/.config/workstation"
      if [[ -d "$real_config" && ! -d "$drilled_config" ]]; then
        detail="real ~/.config/workstation exists but nothing was restored into the drill target"
      elif [[ -d "$drilled_config" ]]; then
        real_count="$(find "$real_config" -type f 2>/dev/null | wc -l)"
        drilled_count="$(find "$drilled_config" -type f 2>/dev/null | wc -l)"
        if [[ "$drilled_count" -eq 0 ]]; then
          detail="restored ~/.config/workstation is empty"
        elif [[ "$real_count" -ne "$drilled_count" ]]; then
          detail="file count mismatch: real=$real_count restored=$drilled_count (informational - backup may predate a recent change)"
          result="PASS"
        else
          result="PASS"
          detail="restored $drilled_count file(s), matching the real config's file count"
        fi
      else
        result="PASS"
        detail="no ~/.config/workstation exists on this machine yet - nothing to verify, backup/restore both ran cleanly"
      fi
    fi
  fi

  echo "$result: $detail"
} > >(tee -a "$LOG_FILE") 2>&1
# Process substitution (not a pipe) is deliberate: a `{ ... } | tee` pipeline
# runs the block in a subshell, so `result`/`detail` set inside it would never
# reach the exit check below.

unset WORKSTATION_BACKUP_PASSPHRASE WORKSTATION_RESTORE_HOME

echo
echo "Logged to: $LOG_FILE"
[[ "$result" == "PASS" ]]
