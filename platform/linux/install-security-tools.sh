#!/usr/bin/env bash
set -euo pipefail

# DevSecOps toolchain: SAST (semgrep), secret scanning (gitleaks + trufflehog),
# IaC scanning (checkov), SCA/container/IaC scanning (trivy), a second-opinion
# CVE scanner + SBOM generator (grype + syft), image signing (cosign), and
# policy-as-code (conftest). Managed via "workstation security", see
# scripts/posix/security.sh and docs/security-scanning.md.
#
# Deliberately sudo-free: every tool here installs into $HOME/.local/bin (or
# a user-level pip/pipx target) rather than a system package - found live
# that routing pipx/trivy through apt (which needs sudo) hangs forever with
# no TTY to answer a password prompt once the cached sudo credential expires,
# the same class of bug already fixed once this session for
# "sudo systemctl enable docker" in scripts/posix/services.sh. A real human
# running bootstrap.sh interactively would just get prompted - but avoiding
# sudo entirely here removes the failure mode altogether, for both cases.

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

# --- pipx-based tools: identical, reliable across every platform this repo
# targets (no default apt/dnf/pacman package for either), installed
# user-level so no sudo is ever needed ---
if ! command -v pipx >/dev/null 2>&1; then
  if python3 -m pip --version >/dev/null 2>&1; then
    python3 -m pip install --user pipx
    python3 -m pipx ensurepath >/dev/null 2>&1 || true
  else
    # Debian/Ubuntu's system python3 deliberately has no pip and refuses
    # ensurepip ("install python3-pip" instead - needs sudo) - found live.
    # A venv's own bundled pip works fine without sudo, so use one just to
    # install pipx, then symlink it onto PATH; pipx manages its own
    # isolated venv per tool from there, same as everywhere else.
    BOOTSTRAP_VENV="$HOME/.local/share/pipx-bootstrap-venv"
    python3 -m venv "$BOOTSTRAP_VENV"
    "$BOOTSTRAP_VENV/bin/pip" install pipx
    ln -sf "$BOOTSTRAP_VENV/bin/pipx" "$BIN_DIR/pipx"
  fi
fi
export PATH="$HOME/.local/bin:$PATH"

command -v semgrep >/dev/null 2>&1 || pipx install semgrep
command -v checkov >/dev/null 2>&1 || pipx install checkov

# Resolve a repo's latest release tag via the redirect target of
# /releases/latest, not the api.github.com endpoint - found live that the
# API endpoint is rate-limited to 60 unauthenticated requests/hour per IP
# and 403s easily; the plain github.com redirect has no such limit.
latest_release_version() {
  local repo="$1"
  local url
  url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' "https://github.com/$repo/releases/latest")"
  printf '%s\n' "${url##*/tag/v}"
}

# --- gitleaks: no default repo package - GitHub release binary ---
if ! command -v gitleaks >/dev/null 2>&1; then
  GITLEAKS_VERSION="$(latest_release_version gitleaks/gitleaks)"
  curl -fsSL "https://github.com/gitleaks/gitleaks/releases/download/v${GITLEAKS_VERSION}/gitleaks_${GITLEAKS_VERSION}_linux_x64.tar.gz" \
    | tar -xz -C "$BIN_DIR" gitleaks
fi

# --- trufflehog: official install script (installs to a target dir, no sudo) ---
command -v trufflehog >/dev/null 2>&1 || \
  curl -sSfL https://raw.githubusercontent.com/trufflesecurity/trufflehog/main/scripts/install.sh \
    | sh -s -- -b "$BIN_DIR"

# --- trivy: Aqua Security's own install script (same, no sudo) rather than
# its apt repo - avoids needing sudo for a repo/gpg-key registration ---
command -v trivy >/dev/null 2>&1 || \
  curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
    | sh -s -- -b "$BIN_DIR"

# --- grype + syft: Anchore's own install scripts (same pattern, binary-only) ---
command -v syft >/dev/null 2>&1 || \
  curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$BIN_DIR"
command -v grype >/dev/null 2>&1 || \
  curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b "$BIN_DIR"

# --- cosign: no default repo package - direct GitHub release binary ---
if ! command -v cosign >/dev/null 2>&1; then
  curl -fsSL -o "$BIN_DIR/cosign" \
    https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
  chmod +x "$BIN_DIR/cosign"
fi

# --- conftest: no default repo package - versioned release asset, resolve tag first ---
if ! command -v conftest >/dev/null 2>&1; then
  CONFTEST_VERSION="$(latest_release_version open-policy-agent/conftest)"
  curl -fsSL "https://github.com/open-policy-agent/conftest/releases/download/v${CONFTEST_VERSION}/conftest_${CONFTEST_VERSION}_Linux_x86_64.tar.gz" \
    | tar -xz -C "$BIN_DIR" conftest
fi

echo "Security toolchain installed. Run 'workstation security doctor' to verify."
