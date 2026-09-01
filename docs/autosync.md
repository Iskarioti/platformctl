# Automatic GitHub Synchronization

Autosync is intentionally scoped to this repository.

It never force-pushes. It does not stage `.env`, keys, certificates, password
databases or named secret directories.

## Windows

A per-user Scheduled Task named `WorkstationSetupAutoSync` runs every 5 minutes.

```powershell
workstation autosync enable
workstation autosync disable
workstation sync
```

## Linux

A systemd user timer runs every 5 minutes when systemd user services are available.

## macOS

A LaunchAgent named `com.workstation.autosync` runs every 5 minutes.

## Conflict behavior

If a remote branch changed, autosync performs a normal pull/rebase. If a conflict
occurs, it leaves the local commit intact and stops. It never force-pushes through a
conflict.

## Pausing during active multi-step work

```powershell
workstation autosync pause [minutes]   # default 30
workstation autosync resume
```

Writes/removes `.state/autosync.pause` (an ISO-8601 UTC expiry timestamp). While
a pause is active and unexpired, autosync's git-sync step is skipped entirely for
that cycle (the unrelated SSH-key-import step still runs). The expiry is a safety
net, not a suggestion to leave it paused: if the file is stale (expiry in the
past), autosync deletes it and proceeds normally on its very next cycle - a
forgotten pause can never disable autosync indefinitely.

## AI agents

Agents can commit normally. The post-commit hook pushes the current branch.
If an agent only edits files and leaves them uncommitted, autosync validates and
commits them on the next cycle - this can interleave an autosync commit into the
middle of a multi-step task. Run `workstation autosync pause` at the start of a
task that touches several already-tracked files across more than one tool call,
and `workstation autosync resume` when the work is committed (or abandoned).

## SSH key import (WSL only)

Each cycle, before any git logic runs, autosync also re-runs
`wsl/import-windows-ssh-keys.sh` (see `docs/new-machine.md`) to copy any new Windows
SSH keys into WSL's native filesystem. This is **local file copying only** and runs
regardless of whether there's anything to git-sync — it never touches git, is
completely independent of the secret-file staging refusal above, and is a no-op on
native Linux/macOS (there's no Windows host to import from). A failure here is
logged but never aborts the git-sync part of the cycle.
