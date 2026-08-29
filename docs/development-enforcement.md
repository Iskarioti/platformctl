# Development Environment Enforcement

## Goal

Bootstrap creates the workstation. Enforcement keeps it compliant and makes new
projects deterministic.

## Workstation compliance

```text
workstation enforce
workstation enforce --repair
```

`--repair` is intentionally limited. It may create missing approved `~/src` project
roots; it does not disable security controls, uninstall software, alter corporate
networking, or silently rewrite application repositories.

## Approved project roots

```text
~/src/company
~/src/platform
~/src/automation
~/src/labs
~/src/tooling
```

On Windows, these paths are inside WSL/Linux. Do not develop application projects
under `/mnt/c`, OneDrive, Downloads, Desktop, or Documents.

## Project lifecycle

```text
workstation project templates
workstation project init fastapi-service hub-notifications --area company
workstation project check
workstation project doctor
workstation project open
```

## Project contract

Governed projects require Git, a Dev Container, `.editorconfig`, `.gitignore`,
`README.md`, `.env.example`, `.platformctl/project.json`, a non-root Dev Container
user, no tracked `.env` secrets, no private-key-like tracked filenames, and no Docker
`:latest` base image.

Lockfiles begin as a warning in v3.1 so a freshly generated project can install its
dependencies first. Change `projects.lockfilePolicy` to `required` once every active
template generates lockfiles during initialization.

## GitHub enforcement

Important repositories should protect `main` with pull requests, blocked force pushes,
required CI checks, and appropriate secret/dependency scanning. Local hooks can be
bypassed and are not authoritative.

## platformctl autosync boundary

The one-minute autosync belongs only to the workstation repository. Do not copy its
auto-commit/auto-push mechanism into product/application repositories.
