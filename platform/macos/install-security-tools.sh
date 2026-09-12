#!/usr/bin/env bash
set -euo pipefail

# DevSecOps toolchain - see platform/linux/install-security-tools.sh for the
# full rationale per tool. Homebrew has a formula for every one of these, so
# macOS needs no GitHub-release/pipx fallback logic.

brew install \
  semgrep gitleaks trufflehog trivy grype syft cosign conftest checkov

echo "Security toolchain installed. Run 'workstation security doctor' to verify."
