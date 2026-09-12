# Workstation Architecture v3.1

## Principle

Git is the source of truth. The live machine is a deployment target. Project
development environments are separately governed by policy and Dev Containers.

```text
GitHub
  ^
  | push current platformctl branch
  |
platformctl repository
  |
  +--> validate source
  +--> apply with cp / Copy-Item
  +--> enforce workstation development policy
  |
  +--> approved project templates
          |
          +--> ~/src/<area>/<project>
                  |
                  +--> Dev Container
                  +--> local project checks
                  +--> GitHub CI / repository rules
```

## Environment tiers

```text
Level 0  Windows/macOS/Linux host
Level 1  WSL/Linux engineering control plane
Level 2  Dev Container project toolchain
Level 3  Docker Compose disposable dependencies
Level 4  Azure/distributed lab for HA/prod-like validation
```

On Windows, project repositories and Docker workloads belong to WSL/Linux. Windows is
the corporate/UI/security control plane.

## Policy boundaries

`workstation.json` controls the workstation source-of-truth contract.

`policy/development.json` controls approved `~/src` roots, WSL-only development on
Windows, Docker-inside-WSL, Dev Container requirements, project structure, secret
handling, container safety, and Git/CI expectations.

Each governed project is created from `templates/projects/*` and receives
`.platformctl/project.json` metadata.

## Commands

```text
workstation validate
workstation doctor
workstation enforce [--repair]
workstation drift-check

workstation project templates
workstation project init <template> <name>
workstation project check [path]
workstation project doctor [path]
workstation project open [path]
```

`--repair` only repairs safe, non-destructive drift such as missing approved project
root directories. `drift-check` verifies the "Git is the source of truth" principle
above actually holds on this machine right now - it compares every running
`dev-*` container against `development/catalog.json` (undeclared containers,
image/version mismatches), rather than assuming the live machine matches what's
declared just because nothing has said otherwise.

Real architectural decisions - a WSL networking mode choice, a `consumes` pattern,
an autosync scope boundary - are recorded in `docs/adr/`, dated and never rewritten
in place (superseded by a new entry instead). This document describes the current
shape; `docs/adr/` explains why it took that shape.

## Git and CI

Local hooks provide fast feedback but are not a security boundary. GitHub CI and
repository protection rules are authoritative.

Application repositories must not inherit platformctl's autosync behavior.
