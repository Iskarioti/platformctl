# Systems & Platform Architect Workstation

A GitHub-first, fully automated, adaptive workstation for Windows, Linux and macOS,
with policy-as-code enforcement for development environments.

The repository is the source of truth. After bootstrap:

- workstation configuration is governed by `workstation.json`;
- development behavior is governed by `policy/development.json`;
- project runtimes live in Dev Containers;
- GitHub CI/rules remain the authoritative merge boundary.


## New machine

### Windows

```powershell
git clone <repo-url>
cd platformctl
.\bootstrap.ps1
```

### Linux / macOS

```bash
git clone <repo-url>
cd platformctl
./bootstrap
```

## Core commands

```text
workstation validate
workstation apply
workstation doctor
workstation enforce
workstation enforce --repair

workstation project templates
workstation project init fastapi-service my-api --area company
workstation project check
workstation project doctor
workstation project open

workstation sync
workstation update
workstation autosync enable
workstation upgrade
workstation autoupgrade enable
workstation dashboard
workstation backup
workstation restore <backup-file>
workstation changelog
```

## Development model

```text
Windows host
  -> WSL2 Ubuntu engineering plane
     -> ~/src/company|platform|automation|labs|tooling
        -> approved project template
           -> VS Code Dev Container
              -> project runtime/toolchain
                 -> local checks
                    -> GitHub CI
                       -> protected PR
```

Project repositories should not live under `/mnt/c`, OneDrive, Desktop, Downloads, or
other Windows-mounted paths when developing on Windows.

`platformctl` autosync only manages this workstation repository. It never auto-commits
or auto-pushes application repositories.

## Approved project templates

- `fastapi-service`
- `react-app`
- `python-service`
- `terraform`
- `research-python`

Create one with:

```bash
workstation project init <template> <name> --area company
```

## Security model

The setup never weakens App Control, WDAC, ConstrainedLanguage, execution policy,
Secure Boot, endpoint controls, or installer verification.

Project policy forbids tracked secret files/private keys, Docker `:latest` base
images, root Dev Container users, and Windows-filesystem development when WSL is the
required engineering plane.

## Documentation

- `docs/architecture.md`
- `docs/development-enforcement.md`
- `docs/new-machine.md`
- `docs/autosync.md`
- `docs/auto-update.md`
- `docs/control-plane.md`
- `docs/reliability.md`
- `docs/ai-agent-maintenance.md`
