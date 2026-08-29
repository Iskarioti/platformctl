#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LOCK="$ROOT/.state/autosync.lock"
mkdir -p "$ROOT/.state"

if ! mkdir "$LOCK" 2>/dev/null; then exit 0; fi
trap 'rmdir "$LOCK" 2>/dev/null || true' EXIT

cd "$ROOT"
[[ -z "$(git status --porcelain)" ]] && exit 0

"$ROOT/setup" validate
"$ROOT/setup" apply --quiet

git add -u

for path in .github .githooks config docs platform policy schema scripts shell templates vscode windows windows-terminal wsl \
            AGENTS.md CLAUDE.md KIMI.md README.md CHANGELOG.md VERSION bootstrap bootstrap.ps1 setup setup.ps1 workstation.json; do
  [[ -e "$path" ]] && git add -- "$path"
done

if git diff --cached --name-only | grep -Ev '(^|/)\.env\.example$' | \
   grep -Eiq '(^|/)(\.env(\..*)?|id_rsa|id_ed25519|secrets?|credentials?)(/|$)|\.(pem|key|pfx|p12|kdbx)$'; then
  echo "Autosync refused: staged files look secret-bearing." >&2
  git reset
  exit 9
fi

git diff --cached --quiet && exit 0

HOST="$(hostname 2>/dev/null || echo workstation)"
STAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
WORKSTATION_AUTOSYNC=1 git commit -m "chore(workstation): autosync ${HOST} ${STAMP}"

BRANCH="$(git branch --show-current)"
[[ -z "$BRANCH" ]] && exit 0

git pull --rebase --autostash origin "$BRANCH" || {
  echo "Autosync committed locally but remote rebase needs manual resolution." >&2
  exit 10
}

git push -u origin "$BRANCH"
