#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
mkdir -p "$HOME/.config/workstation" "$HOME/.local/bin"
printf '%s\n' "$ROOT" > "$HOME/.config/workstation/repo-path"

cat > "$HOME/.local/bin/workstation" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cat "$HOME/.config/workstation/repo-path")"
exec "$ROOT/setup" "$@"
EOF
chmod +x "$HOME/.local/bin/workstation"

PROFILE_FILE="$HOME/.profile"
touch "$PROFILE_FILE"
grep -Fq 'export PATH="$HOME/.local/bin:$PATH"' "$PROFILE_FILE" || \
  printf '\nexport PATH="$HOME/.local/bin:$PATH"\n' >> "$PROFILE_FILE"
