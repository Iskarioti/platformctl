#!/usr/bin/env bash
set -euo pipefail

# Same PATH caveat as scripts/posix/security.sh: invoked from Windows this
# runs as a non-login `wsl.exe -- bash <script>`, which never sources
# .bashrc/.profile, so ~/.local/bin (quarto, pixi) is never on PATH otherwise.
export PATH="$HOME/.local/bin:$PATH"

usage() {
  cat <<'USAGE'
workstation research commands:
  doctor    verify the research computing toolchain is installed
USAGE
}

doctor_line() {
  local state="$1" name="$2" detail="${3:-}"
  printf '%-5s %-10s %s\n' "$state" "$name" "$detail"
}

research_doctor() {
  echo "=== Research Doctor ==="

  if command -v pdflatex >/dev/null 2>&1; then
    doctor_line PASS "latex" "$(pdflatex --version 2>&1 | head -n1)"
  else
    doctor_line MISS "latex" "run: workstation research install (or re-run bootstrap)"
  fi

  for tool in biber latexmk pandoc quarto pixi; do
    if command -v "$tool" >/dev/null 2>&1; then
      doctor_line PASS "$tool" "$("$tool" --version 2>&1 | head -n1)"
    else
      doctor_line MISS "$tool" "run: workstation research install (or re-run bootstrap)"
    fi
  done
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  doctor) research_doctor ;;
  help|-h|--help) usage ;;
  *) echo "Unknown research action: $ACTION" >&2; usage >&2; exit 2 ;;
esac
