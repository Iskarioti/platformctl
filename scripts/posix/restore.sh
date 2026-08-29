#!/usr/bin/env bash
set -euo pipefail

# Restores a backup created by scripts/posix/backup.sh. Deliberately cautious:
# decrypts to a staging area first, shows exactly what would change, and
# requires explicit confirmation before touching anything live. Never
# silently overwrites existing config - it's moved aside with a timestamp
# instead.

INPUT="${1:?Usage: restore.sh <backup-file> [--yes] [--force-volumes]}"
shift || true

ASSUME_YES=0
FORCE_VOLUMES=0
for arg in "$@"; do
  case "$arg" in
    --yes) ASSUME_YES=1 ;;
    --force-volumes) FORCE_VOLUMES=1 ;;
    *) echo "Unknown argument: $arg" >&2; exit 2 ;;
  esac
done

[[ -f "$INPUT" ]] || { echo "ERROR: backup file not found: $INPUT" >&2; exit 2; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "=== Workstation restore ==="
echo "Backup file: $INPUT"
echo ""
echo "Enter the passphrase used to create this backup:"
if [[ -n "${WORKSTATION_BACKUP_PASSPHRASE:-}" ]]; then
  PASSPHRASE="$WORKSTATION_BACKUP_PASSPHRASE"
else
  read -r -s -p "Passphrase: " PASSPHRASE
  echo ""
fi

TARBALL="$WORK/backup.tar.gz"
if ! openssl enc -d -aes-256-cbc -pbkdf2 -pass "pass:$PASSPHRASE" -in "$INPUT" -out "$TARBALL" 2>"$WORK/openssl.err"; then
  echo "ERROR: decryption failed - wrong passphrase, or not a backup created by backup.sh." >&2
  cat "$WORK/openssl.err" >&2
  exit 3
fi
unset PASSPHRASE

STAGE="$WORK/stage"
mkdir -p "$STAGE"
tar xzf "$TARBALL" -C "$STAGE"

if [[ ! -f "$STAGE/manifest.json" ]]; then
  echo "ERROR: this does not look like a workstation backup (no manifest.json)." >&2
  exit 4
fi

echo ""
echo "This backup contains:"
[[ -d "$STAGE/config-workstation" ]] && echo "  - ~/.config/workstation (control-plane credentials, dev-service secrets)"
[[ -d "$STAGE/labs-state" ]] && echo "  - ~/.local/state/platformctl/labs"
if [[ -d "$STAGE/volumes" ]]; then
  for f in "$STAGE"/volumes/*.tar.gz; do
    [[ -e "$f" ]] || continue
    echo "  - Docker volume: $(basename "$f" .tar.gz)"
  done
fi

echo ""
if [[ "$ASSUME_YES" -ne 1 ]]; then
  read -r -p "Restore this onto the current machine? [y/N] " confirm
  [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { echo "Aborted, nothing changed."; exit 0; }
fi

if [[ -d "$STAGE/config-workstation" ]]; then
  if [[ -d "$HOME/.config/workstation" ]]; then
    moved="$HOME/.config/workstation.pre-restore.$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$HOME/.config/workstation" "$moved"
    echo "Existing ~/.config/workstation moved aside to: $moved"
  fi
  mkdir -p "$HOME/.config"
  cp -a "$STAGE/config-workstation" "$HOME/.config/workstation"
  chmod -R go-rwx "$HOME/.config/workstation" 2>/dev/null || true
  echo "Restored: ~/.config/workstation"
fi

if [[ -d "$STAGE/labs-state" ]]; then
  target="$HOME/.local/state/platformctl/labs"
  if [[ -d "$target" ]]; then
    moved="$target.pre-restore.$(date -u +%Y%m%dT%H%M%SZ)"
    mv "$target" "$moved"
    echo "Existing labs state moved aside to: $moved"
  fi
  mkdir -p "$(dirname "$target")"
  cp -a "$STAGE/labs-state" "$target"
  echo "Restored: $target"
fi

if [[ -d "$STAGE/volumes" ]] && command -v docker >/dev/null 2>&1; then
  for f in "$STAGE"/volumes/*.tar.gz; do
    [[ -e "$f" ]] || continue
    volume="$(basename "$f" .tar.gz)"

    if docker volume inspect "$volume" >/dev/null 2>&1 && [[ "$FORCE_VOLUMES" -ne 1 ]]; then
      echo "SKIPPED volume $volume: already exists on this machine (pass --force-volumes to overwrite its data)."
      continue
    fi

    docker volume create "$volume" >/dev/null
    docker run --rm \
      -v "$volume:/target" \
      -v "$STAGE/volumes:/backup:ro" \
      alpine:3.20 \
      sh -c "rm -rf /target/* /target/..?* /target/.[!.]* 2>/dev/null; tar xzf /backup/$volume.tar.gz -C /target"
    echo "Restored: Docker volume $volume"
  done
fi

echo ""
echo "Restore complete. Review docs/control-plane.md if you restored control-plane credentials."
