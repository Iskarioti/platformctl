#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/policy/development.json"
REPAIR=0
[[ "${1:-}" == "--repair" ]] && REPAIR=1

failures=0
warnings=0
pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1" >&2; warnings=$((warnings+1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures=$((failures+1)); }

echo "=== WSL/POSIX Development Enforcement ==="

[[ -f "$POLICY" ]] || { echo "Development policy missing: $POLICY" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "jq is required for policy enforcement." >&2; exit 2; }

grep -qi microsoft /proc/version 2>/dev/null && pass "Running inside WSL"

for tool in git jq; do
  if command -v "$tool" >/dev/null 2>&1; then pass "$tool available"; else fail "$tool missing"; fi
done

if command -v docker >/dev/null 2>&1; then
  pass "Docker CLI available"
  if docker info >/dev/null 2>&1; then
    pass "Docker Engine reachable"
  else
    warn "Docker CLI is installed but Docker Engine is not currently reachable"
  fi
else
  fail "Docker is required in the Linux/WSL engineering plane"
fi

if command -v code >/dev/null 2>&1; then
  pass "VS Code WSL command available"
else
  warn "VS Code 'code' command is not currently available in this shell"
fi

while IFS= read -r configured; do
  expanded="${configured/#\~/$HOME}"
  if [[ -d "$expanded" ]]; then
    pass "Project root exists: $expanded"
  elif [[ "$REPAIR" -eq 1 ]]; then
    mkdir -p "$expanded"
    pass "Created project root: $expanded"
  else
    fail "Project root missing: $expanded (run workstation enforce --repair)"
  fi
done < <(jq -r '.projectRoots[]' "$POLICY")

if [[ -x "$HOME/.local/bin/workstation" ]]; then
  pass "POSIX workstation command installed"
else
  warn "POSIX workstation command not installed yet; run the Linux bootstrap"
fi

echo
echo "Failures: $failures"
echo "Warnings: $warnings"

if [[ "$failures" -gt 0 ]]; then
  echo "RESULT: NON-COMPLIANT"
  exit 1
fi

echo "RESULT: COMPLIANT"
exit 0
