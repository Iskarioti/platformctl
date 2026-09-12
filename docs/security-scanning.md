# Security Scanning (DevSecOps)

`workstation security` - a single command wrapping the current (2026) standard
open-source DevSecOps toolchain, installed on WSL/Linux and macOS (governed
project code lives under WSL's `~/src/*` per policy, so scanning always runs
there - see `scripts/common/security.ps1` for the Windows-side dispatch into
WSL, matching `services`/`editor`/`models`).

```bash
workstation security doctor       # verify every tool is installed
workstation security scan [path]  # run the full suite (default: .)
workstation security sbom [path] [out]   # CycloneDX SBOM via syft
```

## Toolchain

| Category | Tool | Why this one |
|---|---|---|
| SAST | [Semgrep](https://semgrep.dev) | current open-source standard |
| Secret scanning | [Gitleaks](https://github.com/gitleaks/gitleaks) + [TruffleHog](https://github.com/trufflesecurity/trufflehog) | Gitleaks is fast/pre-commit-friendly; TruffleHog additionally verifies whether a found credential is still live |
| SCA / container / IaC | [Trivy](https://trivy.dev) | one tool covers vulnerabilities, secrets, misconfig, and license in a single filesystem/image/repo scan |
| Second-opinion CVE scan + SBOM | [Grype](https://github.com/anchore/grype) + [Syft](https://github.com/anchore/syft) | Anchore's pair - Syft generates the SBOM, Grype scans it |
| IaC scanning | [Checkov](https://www.checkov.io) | 800+ graph-based cross-resource checks that single-file Rego scanners don't replicate |
| Image signing | [Cosign](https://docs.sigstore.dev) | Sigstore/CNCF standard - keyless OIDC signing over long-lived keys |
| Policy-as-code | [Conftest](https://www.conftest.dev) | OPA/Rego, single binary - fits a workstation/CI gate (Kyverno is cluster-admission-control, a different problem) |

`tfsec` and `terrascan` are deliberately not used: tfsec merged into Trivy
(`trivy config` replaces it, same check IDs); terrascan is archived.

## Installation

`platform/linux/install-security-tools.sh` and `platform/macos/
install-security-tools.sh` (both run from their OS's `bootstrap.sh`).
Deliberately sudo-free on Linux: Semgrep/Checkov install via a user-level
`pipx` (bootstrapped through a throwaway venv if the system `python3` has no
`pip` - Debian/Ubuntu's system Python deliberately excludes it and refuses
`ensurepip`, confirmed live), everything else via each project's own official
install script into `~/.local/bin`. On macOS, Homebrew has a formula for every
one of these tools directly.

Version resolution for tools without a package-manager listing (Gitleaks,
Conftest) uses the redirect target of a GitHub repo's `/releases/latest` URL,
not the `api.github.com` REST endpoint - found live that the API endpoint
rate-limits unauthenticated requests to 60/hour per IP and 403s easily; the
plain `github.com` redirect has no such limit.

## `workstation security scan` findings feed back into the repo itself

Running the new scanner against this repo's own project templates found a
real issue, not a hypothetical one: every template's `.github/workflows/{ci,
policy}.yml` referenced GitHub Actions by a mutable tag
(`actions/checkout@v4`, etc.) - Semgrep's own
`github-actions-mutable-action-tag` rule flags this as a real supply-chain
risk (a tag can be silently repointed by the action owner). Fixed across all
11 templates: every `actions/checkout`, `actions/setup-python`,
`actions/setup-node`, and `hashicorp/setup-terraform` reference is now pinned
to its exact commit SHA (resolved via `git ls-remote`, not the rate-limited
API), with a `# vN` comment for readability. Re-scanning confirmed 0 findings
afterward.

## CI wiring

`azure-pipelines/python-service.yml` had a literal "Add Trivy/SBOM steps"
TODO comment, never implemented - now runs `trivy image --severity
CRITICAL,HIGH` against the built container and publishes a `syft`-generated
CycloneDX SBOM as a pipeline artifact, using the same install scripts as the
workstation-level tooling.
