#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <template> <destination>"
  echo "Templates: fastapi-service infra network-automation ai"
  exit 2
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE="$1"
DEST="$2"

SOURCE="$ROOT/templates/$TEMPLATE"

if [[ ! -d "$SOURCE" ]]; then
  echo "Unknown template: $TEMPLATE"
  exit 2
fi

if [[ -e "$DEST" ]]; then
  echo "Destination already exists: $DEST"
  exit 2
fi

cp -a "$SOURCE" "$DEST"
cd "$DEST"
git init -b main

echo "Created $DEST from $TEMPLATE"
echo "Next:"
echo "  cd $DEST"
echo "  code ."
echo "  Reopen in Container"
