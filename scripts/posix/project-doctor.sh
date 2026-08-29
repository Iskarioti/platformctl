#!/usr/bin/env bash
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="${1:-$PWD}"

"$ROOT/scripts/posix/project-check.sh" "$TARGET"
status=$?

echo
echo "=== Project Doctor ==="
echo "Path: $(realpath "$TARGET" 2>/dev/null || printf '%s' "$TARGET")"
echo "Filesystem: $(df -T "$TARGET" 2>/dev/null | awk 'NR==2 {print $2}' || true)"
echo "Branch: $(git -C "$TARGET" branch --show-current 2>/dev/null || echo n/a)"
echo "Git: $(git --version 2>/dev/null || echo missing)"
echo "Docker: $(docker --version 2>/dev/null || echo missing)"
echo "Code: $(code --version 2>/dev/null | head -n1 || echo missing)"
echo "Python: $(python3 --version 2>/dev/null || echo missing)"
echo "Node: $(node --version 2>/dev/null || echo missing)"
echo "Terraform: $(terraform version 2>/dev/null | head -n1 || echo missing)"
exit "$status"
