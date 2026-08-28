#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPO="${1:-Iskarioti/system-platform-architect-workstation}"
VISIBILITY="${2:---private}"

cd "$ROOT"
command -v gh >/dev/null 2>&1 || { echo "gh is required"; exit 2; }
gh auth status

if git remote get-url origin >/dev/null 2>&1; then
  echo "origin already exists: $(git remote get-url origin)"
  exit 0
fi

gh repo create "$REPO" "$VISIBILITY" --source . --remote origin --push
