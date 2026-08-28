# AGENTS.md — Workstation Repository Contract

This repository is the **single source of truth** for the workstation.

## Mission

Maintain an advanced, adaptive, reproducible workstation for a Systems & Platform
Architect across Windows, Linux and macOS.

## Non-negotiable rules

1. Edit repository source files, never deployed dotfiles as the primary change.
2. Use `cp` / `Copy-Item` semantics for deployment. Do not introduce `rsync`.
3. Never weaken execution policy, App Control, WDAC, ConstrainedLanguage, Secure Boot,
   endpoint security, or corporate controls to make automation work.
4. Never commit secrets, private keys, tokens, `.env` files, credentials, or
   machine-specific confidential data.
5. The editor font is **official JetBrains Mono from JetBrains**.
6. The terminal font is **JetBrainsMono Nerd Font Mono** from Nerd Fonts.
7. Windows Terminal exposes one shell only: PowerShell 7 GUID
   `{574e775e-4f2a-5b96-ac1e-a2962a402336}`.
8. Docker on Windows lives inside WSL, not Docker Desktop.
9. Every platform-specific change must remain idempotent.
10. Run `workstation validate` and `workstation doctor` before considering a change done.

## Architecture

Canonical source -> validate -> apply with cp -> commit -> push current branch.

The background autosync service performs this loop only after the repository is
valid. Git hooks validate commits and push normal commits automatically.

## Agent workflow

```text
1. Read AGENTS.md and docs/architecture.md.
2. Inspect workstation.json.
3. Make the smallest coherent source change.
4. Run workstation validate.
5. Run workstation apply.
6. Run workstation doctor when platform access is available.
7. Commit with a meaningful message.
8. The post-commit hook pushes the current branch automatically.
```

For larger changes, create a feature branch first. Auto-push follows the current
branch and does not force-push.

## Required documentation

Update CHANGELOG.md for behavior changes. Update docs when commands, file locations,
platform support, automation or security behavior changes.
