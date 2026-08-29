#!/usr/bin/env bash
set -euo pipefail

# Backs up everything a hardware failure would otherwise destroy silently:
# control-plane credentials/config, dev-service secrets, labs state, and the
# named Docker volumes behind postgres/redis/grafana/etc. The git repo itself
# is already safe (it's on GitHub) - this is for the state that deliberately
# lives OUTSIDE the repo per AGENTS.md rule 4 (never commit secrets).
#
# Passphrase-encrypted with openssl (already a required tool in this repo) -
# no new dependency, no plaintext secrets ever touch disk unencrypted for
# longer than the few seconds it takes to tar+encrypt.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUTPUT="${1:-$HOME/workstation-backups/workstation-backup-$(date -u +%Y%m%dT%H%M%SZ).tar.gz.enc}"

mkdir -p "$(dirname "$OUTPUT")"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
STAGE="$WORK/stage"
mkdir -p "$STAGE"

echo "=== Workstation backup ==="

if [[ -d "$HOME/.config/workstation" ]]; then
  mkdir -p "$STAGE/config-workstation"
  cp -a "$HOME/.config/workstation/." "$STAGE/config-workstation/"
  echo "Included: ~/.config/workstation (control-plane credentials, dev-service secrets)"
else
  echo "Skipped: ~/.config/workstation does not exist on this machine yet"
fi

LABS_STATE="$HOME/.local/state/platformctl/labs"
if [[ -d "$LABS_STATE" ]]; then
  mkdir -p "$STAGE/labs-state"
  cp -a "$LABS_STATE/." "$STAGE/labs-state/"
  echo "Included: $LABS_STATE"
else
  echo "Skipped: no labs state directory on this machine yet"
fi

if command -v docker >/dev/null 2>&1; then
  mkdir -p "$STAGE/volumes"
  volumes="$(docker volume ls --filter name=platform --format '{{.Name}}' 2>/dev/null || true)"
  if [[ -n "$volumes" ]]; then
    while IFS= read -r volume; do
      [[ -z "$volume" ]] && continue
      echo "Included: Docker volume $volume"
      docker run --rm \
        -v "$volume:/source:ro" \
        -v "$STAGE/volumes:/backup" \
        alpine:3.20 \
        tar czf "/backup/$volume.tar.gz" -C /source .
    done <<< "$volumes"
  else
    echo "Skipped: no platform-* Docker volumes exist on this machine yet"
  fi
else
  echo "Skipped: docker is not available, no volumes backed up"
fi

MANIFEST="$STAGE/manifest.json"
python3 - "$MANIFEST" <<'PY'
import json, sys, datetime
json.dump(
    {"created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "format": "workstation-backup-v1"},
    open(sys.argv[1], "w"),
)
PY

TARBALL="$WORK/backup.tar.gz"
tar czf "$TARBALL" -C "$STAGE" .

echo ""
echo "Enter a passphrase to encrypt this backup (you will need it to restore):"
if [[ -n "${WORKSTATION_BACKUP_PASSPHRASE:-}" ]]; then
  # Scripting/CI only - prefer the interactive prompt for real use so the
  # passphrase never sits in shell history or a CI log.
  PASSPHRASE="$WORKSTATION_BACKUP_PASSPHRASE"
else
  read -r -s -p "Passphrase: " PASSPHRASE
  echo ""
  read -r -s -p "Confirm passphrase: " PASSPHRASE_CONFIRM
  echo ""
  if [[ "$PASSPHRASE" != "$PASSPHRASE_CONFIRM" ]]; then
    echo "ERROR: passphrases did not match." >&2
    exit 2
  fi
fi

if [[ -z "$PASSPHRASE" ]]; then
  echo "ERROR: an empty passphrase is not allowed." >&2
  exit 2
fi

openssl enc -aes-256-cbc -pbkdf2 -salt -pass "pass:$PASSPHRASE" -in "$TARBALL" -out "$OUTPUT"
unset PASSPHRASE PASSPHRASE_CONFIRM

chmod 600 "$OUTPUT"

echo ""
echo "Backup written: $OUTPUT"
echo "SHA256: $(openssl dgst -sha256 "$OUTPUT" | awk '{print $2}')"
echo ""
echo "Store this file (and remember the passphrase) somewhere other than this machine."
