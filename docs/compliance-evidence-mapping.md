# Compliance Evidence Mapping

This repo isn't certified against anything, and this document doesn't claim
otherwise. What it does map is real, already-built mechanisms in this repo
to the *kind* of evidence a SOC 2 or ISO/IEC 27001 auditor typically asks
for - useful for a Platform/Systems Engineer preparing an actual company's
control environment (or evaluating whether their tooling could), not a
substitute for a real audit, a real risk assessment, or legal/compliance
review. Treat every row as "here's where the evidence lives," not "this
control is satisfied."

| Control area | SOC 2 TSC | ISO/IEC 27001 theme | Evidence in this repo |
|---|---|---|---|
| Vulnerability management | Security (CC7) | Technological controls | `workstation security scan` (Semgrep/Gitleaks/TruffleHog/Trivy/Checkov) wired into every template's CI (`security.yml`), with results persisted (`.state/security/last-scan.json`, `.platformctl/security-scan.json`) and staleness-checked by `workstation doctor`/`project doctor` - see `docs/security-scanning.md` |
| Software composition / SBOM | Security (CC7) | Technological controls | `workstation security sbom` (Syft, CycloneDX format) - a generated artifact, not a policy statement |
| Secure change management | Security (CC8) | Organizational controls | Git history itself, plus `docs/adr/` (Architecture Decision Records - every non-obvious infrastructure decision has a dated, never-deleted rationale record) and required CI gates (`ci.yml`/`policy.yml`/`security.yml`) before merge |
| Access control | Security (CC6) | Organizational + Technological controls | `docs/control-plane.md`: scrypt-hashed password + TOTP, signed session cookies with server-side revocation, login backoff. Per-service credentials generated per machine (`~/.config/workstation/services/*.env`), never shared/committed |
| Credential rotation | Security (CC6) | Technological controls | `docs/secrets-rotation.md` + `workstation services rotate <service>` (automated where verified safe; documented manual procedure everywhere else, not silently skipped) |
| Backup and recovery | Availability (A1) | Technological controls | `workstation backup`/`restore`, and critically `workstation dr-drill` - the *proof* the backup is actually restorable, not just a script that's never been run for real (see `docs/reliability.md`) |
| Dependency/patch management | Security (CC7) | Technological controls | `.github/dependabot.yml` in every template (`docs/dependency-updates.md`) - grouped weekly PRs, not a manual "remember to check" process |
| Policy as code | Security (CC5) | Organizational controls | `policy/development.json` (`allowedTemplates`, `projectRoots`, lock policy) enforced by `workstation enforce`, not just documented as a convention |
| Monitoring / observability | Availability (A1) | Technological controls | The `observability` dev-service profile (Prometheus/Loki/Tempo/Grafana/cAdvisor), plus `.state/usage.jsonl` + `workstation catalog stats` for what's actually being used |
| Incident/audit trail | Security (CC7) | Organizational controls | Control plane's audit log (`docs/control-plane.md` "Audit log"), plus every dev-service action already going through a single auditable CLI surface (`workstation services ...`) rather than untracked manual `docker` commands |
| Least privilege (AI/agentic systems) | Security (CC6), Confidentiality (C1) | Technological controls | `mcp-server`/`rag-app`/`agent-app` templates' own "Threat model" README sections (OWASP LLM Top 10-mapped) - excessive agency, insecure tool design, and injection risks documented per-template, not left implicit |
| Configuration management | Security (CC8) | Technological controls | Every dev-service is declarative (`compose.yaml` + `service.json`), version-pinned (`versions.env`), and config-independent of its dependencies (`docs/adr/0003`) - no undocumented drift between what's running and what's in Git |

## What this deliberately does not cover

- **Legal/contractual controls** (DPAs, vendor risk assessments, retention
  policy sign-off) - organizational, not tooling, and out of scope for a
  workstation repo.
- **Physical security** - this is a single-developer workstation, not a
  datacenter.
- **Formal risk assessment / risk register** - this table is evidence
  inventory, not a risk assessment; a real audit still needs one.
- **Multi-user access review** - the control plane is explicitly
  single-operator (`docs/control-plane.md`); a real org's user-access-review
  control needs an actual multi-user identity system, not this.

## Using this for a real audit

Point an auditor at the specific file/command in the "Evidence" column, not
this table itself - this table is an index for you, not a document to hand
over as the evidence itself. Re-verify every row still matches reality
before relying on it (this file decays exactly like any other doc the
moment a mechanism it describes changes) - the same standing rule this
whole repo maintenance process already follows.
