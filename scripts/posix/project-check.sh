#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
POLICY="$ROOT/policy/development.json"
TARGET="${1:-$PWD}"

command -v jq >/dev/null 2>&1 || { echo "FAIL  jq is required" >&2; exit 2; }

TARGET="$(realpath "$TARGET" 2>/dev/null || printf '%s' "$TARGET")"
failures=0
warnings=0
pass() { printf 'PASS  %s\n' "$1"; }
warn() { printf 'WARN  %s\n' "$1" >&2; warnings=$((warnings+1)); }
fail() { printf 'FAIL  %s\n' "$1" >&2; failures=$((failures+1)); }

echo "=== Project Policy Check ==="
echo "Project: $TARGET"
echo

approved=0
while IFS= read -r configured; do
  expanded="${configured/#\~/$HOME}"
  case "$TARGET/" in "$expanded/"*) approved=1; break ;; esac
done < <(jq -r '.projectRoots[]' "$POLICY")

if [[ "$approved" -eq 1 ]]; then
  pass "Project is inside an approved ~/src root"
else
  fail "Project must live under an approved project root from policy/development.json"
fi

case "$TARGET" in
  /mnt/[a-zA-Z]/*)
    if jq -e '.windows.allowProjectsOnWindowsFilesystem == false' "$POLICY" >/dev/null; then
      fail "Project is on the Windows filesystem; use the WSL/Linux filesystem"
    fi
    ;;
esac

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  pass "Git repository"
else
  fail "Git repository required"
fi

required=(
  ".devcontainer/devcontainer.json"
  ".editorconfig"
  ".gitignore"
  "README.md"
  ".env.example"
  ".platformctl/project.json"
  ".github/workflows/ci.yml"
  ".github/workflows/policy.yml"
)

for rel in "${required[@]}"; do
  if [[ -e "$TARGET/$rel" ]]; then pass "Required file: $rel"; else fail "Required file missing: $rel"; fi
done

DEV="$TARGET/.devcontainer/devcontainer.json"
if [[ -f "$DEV" ]]; then
  if jq empty "$DEV" >/dev/null 2>&1; then
    pass "devcontainer.json is valid JSON"
    remote_user="$(jq -r '.remoteUser // empty' "$DEV")"
    if jq -e '.containers.requireNonRootDevContainer' "$POLICY" >/dev/null; then
      if [[ -n "$remote_user" && "$remote_user" != "root" ]]; then
        pass "Dev Container remoteUser is non-root ($remote_user)"
      else
        fail "Dev Container must declare a non-root remoteUser"
      fi
    fi
  else
    fail "devcontainer.json is invalid JSON"
  fi
fi

if git -C "$TARGET" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  tracked_env="$(
    git -C "$TARGET" ls-files |
      grep -E '(^|/)\.env($|\.)' |
      grep -vE '(^|/)\.env\.example$' || true
  )"
  if [[ -n "$tracked_env" ]]; then
    fail "Tracked .env-style files detected: $(echo "$tracked_env" | tr '\n' ' ')"
  else
    pass "No tracked .env secret files"
  fi

  secret_names="$(
    git -C "$TARGET" ls-files |
      grep -Ei '(^|/)(id_rsa|id_ed25519|secrets?|credentials?)(/|$)|\.(pem|key|pfx|p12|kdbx)$' || true
  )"
  if [[ -n "$secret_names" ]]; then
    fail "Secret-like tracked filenames detected: $(echo "$secret_names" | tr '\n' ' ')"
  else
    pass "No obvious private-key/secret filenames tracked"
  fi

  branch="$(git -C "$TARGET" branch --show-current 2>/dev/null || true)"
  if [[ "$branch" == "main" ]]; then
    warn "Currently on main; create a feature branch before normal development"
  elif [[ -n "$branch" ]]; then
    pass "Development branch: $branch"
  fi
fi

if jq -e '.containers.forbidLatestTag' "$POLICY" >/dev/null; then
  latest_hits="$(
    find "$TARGET" -type f \( -name 'Dockerfile' -o -name 'Dockerfile.*' \) -not -path '*/.git/*' -print0 2>/dev/null |
      xargs -0 grep -HnEi '^[[:space:]]*FROM[[:space:]]+[^[:space:]]+:latest([[:space:]]|$)' 2>/dev/null || true
  )"
  if [[ -n "$latest_hits" ]]; then
    fail "Docker :latest base image found"
    printf '%s\n' "$latest_hits" >&2
  else
    pass "No Docker :latest base image"
  fi
fi

lock_policy="$(jq -r '.projects.lockfilePolicy' "$POLICY")"
has_manifest=0
has_lock=0

if [[ -f "$TARGET/pyproject.toml" || -f "$TARGET/package.json" ]]; then
  has_manifest=1
fi

if [[ -f "$TARGET/uv.lock" || -f "$TARGET/poetry.lock" || -f "$TARGET/requirements.lock" ||
      -f "$TARGET/package-lock.json" || -f "$TARGET/pnpm-lock.yaml" || -f "$TARGET/yarn.lock" ||
      -f "$TARGET/.terraform.lock.hcl" ]]; then
  has_lock=1
fi

if [[ "$has_manifest" -eq 1 && "$has_lock" -eq 0 ]]; then
  if [[ "$lock_policy" == "required" ]]; then
    fail "Dependency manifest exists but no recognized lockfile exists"
  else
    warn "Generate and commit a dependency lockfile before production use"
  fi
elif [[ "$has_lock" -eq 1 ]]; then
  pass "Dependency lockfile present"
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
