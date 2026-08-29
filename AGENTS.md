# AGENTS.md — Workstation Repository Contract

This repository is the **single source of truth** for the workstation and its
development-environment policy.

## Mission

Maintain an advanced, adaptive, reproducible workstation for a Systems & Platform
Architect across Windows, Linux and macOS, and enforce deterministic development
environments for projects created or operated through `platformctl`.

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
10. Run `workstation validate` and `workstation doctor` before considering a
    workstation-source change done.
11. Governed application projects live under approved `~/src/*` roots on the Linux/WSL
    filesystem and use Dev Containers for project-specific toolchains.
12. Do not weaken project CI, secret scanning, branch protection, dependency scanning,
    non-root container requirements, or pinned-version policy to make a change pass.
13. `platformctl` autosync manages **platformctl only**. Never add automatic commit/push
    behavior to application repositories.

## Development policy

`policy/development.json` is authoritative for development-environment behavior.

Project creation and checks use:

```text
workstation enforce
workstation project templates
workstation project init <template> <name>
workstation project check
workstation project doctor
workstation project open
```

Project-local Git hooks are convenience controls. GitHub CI and repository rules are
the authoritative merge boundary.

## Agent workflow

1. Read `AGENTS.md` and `docs/architecture.md`.
2. Inspect `workstation.json` and `policy/development.json`.
3. Make the smallest coherent source change.
4. Run `workstation validate`.
5. Run `workstation apply` when workstation configuration changed.
6. Run `workstation enforce` when development policy/platform behavior changed.
7. Run `workstation project check` inside affected project templates/projects.
8. Commit with a meaningful message.
9. The post-commit hook pushes the current platformctl branch automatically.

For larger changes, create a feature branch first. Auto-push follows the current
platformctl branch and does not force-push.

## Required documentation

Update `CHANGELOG.md` for behavior changes. Update docs when commands, file locations,
platform support, automation, development policy, project templates, or security
behavior changes.
