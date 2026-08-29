# Automatic GitHub Synchronization

Autosync is intentionally scoped to this repository.

It never force-pushes. It does not stage `.env`, keys, certificates, password
databases or named secret directories.

## Windows

A per-user Scheduled Task named `WorkstationSetupAutoSync` runs once per minute.

```powershell
workstation autosync enable
workstation autosync disable
workstation sync
```

## Linux

A systemd user timer runs once per minute when systemd user services are available.

## macOS

A LaunchAgent named `com.workstation.autosync` runs once per minute.

## Conflict behavior

If a remote branch changed, autosync performs a normal pull/rebase. If a conflict
occurs, it leaves the local commit intact and stops. It never force-pushes through a
conflict.

## AI agents

Agents can commit normally. The post-commit hook pushes the current branch.
If an agent only edits files and leaves them uncommitted, autosync validates and
commits them on the next cycle.

## SSH key import (WSL only)

Each cycle, before any git logic runs, autosync also re-runs
`wsl/import-windows-ssh-keys.sh` (see `docs/new-machine.md`) to copy any new Windows
SSH keys into WSL's native filesystem. This is **local file copying only** and runs
regardless of whether there's anything to git-sync — it never touches git, is
completely independent of the secret-file staging refusal above, and is a no-op on
native Linux/macOS (there's no Windows host to import from). A failure here is
logged but never aborts the git-sync part of the cycle.
