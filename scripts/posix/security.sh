#!/usr/bin/env bash
set -euo pipefail

# Every tool here installs to ~/.local/bin (see platform/{linux,macos}/
# install-security-tools.sh) - fine for an interactive login shell, but
# invoked from Windows this runs as a plain non-login `wsl.exe -- bash
# <script>`, which never sources .bashrc/.profile and so never puts
# ~/.local/bin on PATH. Found live: every tool showed MISS from Windows
# despite being installed. Set it explicitly rather than depend on shell
# startup files having already run.
export PATH="$HOME/.local/bin:$PATH"

usage() {
  cat <<'USAGE'
workstation security commands:
  scan [path]           run the full scan suite against path (default: .)
                         semgrep, gitleaks, trufflehog, trivy fs, checkov
  sbom [path] [out]     generate a CycloneDX SBOM for path (default: ., stdout)
  doctor                verify every security tool is installed
USAGE
}

need_tool() {
  command -v "$1" >/dev/null 2>&1
}

doctor_line() {
  local state="$1" name="$2" detail="${3:-}"
  printf '%-5s %-12s %s\n' "$state" "$name" "$detail"
}

security_doctor() {
  echo "=== Security Doctor ==="
  local tool version
  for tool in semgrep gitleaks trufflehog trivy grype syft cosign conftest checkov; do
    if need_tool "$tool"; then
      # cosign is the one CLI here that rejects --version outright
      # ("unknown flag") and needs its bare "version" subcommand instead -
      # found live, every other tool accepts --version fine.
      if [[ "$tool" == "cosign" ]]; then
        version="$(cosign version 2>&1 | grep -m1 'GitVersion' || cosign version 2>&1 | head -n1)"
      else
        version="$("$tool" --version 2>&1 | head -n1)"
      fi
      doctor_line PASS "$tool" "$version"
    else
      doctor_line MISS "$tool" "run: workstation security install (or re-run bootstrap)"
    fi
  done
}

security_scan() {
  local target="${1:-.}"
  local failures=0

  echo "=== Security Scan: $target ==="

  if need_tool semgrep; then
    echo; echo "--- semgrep (SAST) ---"
    semgrep --config auto --error "$target" || failures=$((failures + 1))
  else
    echo "SKIP semgrep (not installed)"
  fi

  if need_tool gitleaks; then
    echo; echo "--- gitleaks (secret scanning) ---"
    gitleaks detect --source "$target" --no-banner || failures=$((failures + 1))
  else
    echo "SKIP gitleaks (not installed)"
  fi

  if need_tool trufflehog; then
    echo; echo "--- trufflehog (secret scanning, verifies live credentials) ---"
    trufflehog filesystem "$target" --fail || failures=$((failures + 1))
  else
    echo "SKIP trufflehog (not installed)"
  fi

  if need_tool trivy; then
    echo; echo "--- trivy (vuln/secret/misconfig/license, filesystem) ---"
    trivy fs --exit-code 1 "$target" || failures=$((failures + 1))
  else
    echo "SKIP trivy (not installed)"
  fi

  if need_tool checkov; then
    echo; echo "--- checkov (IaC scanning) ---"
    checkov -d "$target" --compact || failures=$((failures + 1))
  else
    echo "SKIP checkov (not installed)"
  fi

  echo
  if [[ "$failures" -eq 0 ]]; then
    echo "RESULT: clean (0 tools reported findings)"
  else
    echo "RESULT: $failures tool(s) reported findings - see output above"
  fi
  return "$failures"
}

security_sbom() {
  local target="${1:-.}"
  local out="${2:-}"

  need_tool syft || { echo "ERROR: syft is not installed - run bootstrap or platform/{linux,macos}/install-security-tools.sh" >&2; exit 2; }

  if [[ -n "$out" ]]; then
    syft "$target" -o cyclonedx-json="$out"
    echo "SBOM written to $out"
  else
    syft "$target" -o cyclonedx-json
  fi
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  scan) security_scan "$@" ;;
  sbom) security_sbom "$@" ;;
  doctor) security_doctor ;;
  help|-h|--help) usage ;;
  *) echo "Unknown security action: $ACTION" >&2; usage >&2; exit 2 ;;
esac
