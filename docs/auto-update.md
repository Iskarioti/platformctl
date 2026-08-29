# Automatic Component Upgrades

`autosync` (see `docs/autosync.md`) keeps this git repository in sync. It does not
touch installed software. `workstation upgrade` / `autoupgrade` is the separate
mechanism that keeps installed components current: winget/brew/apt-managed packages,
VS Code extensions, and pinned fonts.

## Scope

Controlled by `workstation.json`'s `autoUpdate` block:

```json
"autoUpdate": {
  "enabled": true,
  "scope": ["packages", "vscodeExtensions", "fonts"],
  "schedule": { "windowStart": "22:00", "windowEnd": "06:00" },
  "skipIfContainersRunning": true
}
```

- `packages` re-runs the platform package installer (`windows/10-install-tools.ps1`'s
  `winget upgrade` step; `brew upgrade` for the curated formula/cask list on macOS;
  `apt/dnf/pacman` upgrade of the curated list on Linux) — the same curated tool list
  bootstrap installs, never a blanket whole-system upgrade.
- `vscodeExtensions` re-runs the existing `--force` extension install loop.
- `fonts` re-runs the idempotent, version-pinned font installer.

**Deliberately out of scope:** exact-pinned Docker image tags in
`development/*/versions.env` and `labs/**`, and project-template versions. Those need
changelog-aware human judgment, not blind automation.

## On demand

```powershell
workstation upgrade
workstation upgrade -Scope fonts
```

Manual runs skip the quiet-hours window and the container-activity check (running it
yourself is explicit consent). Every run logs to `.state/upgrade-<date>.log`.

## Off-hours background worker

```powershell
workstation autoupgrade enable
workstation autoupgrade disable
workstation autoupgrade status
```

- **Windows**: a Scheduled Task named `WorkstationAutoUpgrade`, triggered daily at
  `autoUpdate.schedule.windowStart`, running with the highest available privileges
  (silently, without a UAC prompt, for an administrator account) since the `packages`
  scope needs the same elevation `windows/10-install-tools.ps1` already requires.
- **Linux**: a systemd user timer (`workstation-autoupgrade.timer`), daily at the
  configured time. The `packages` scope uses `sudo`; an unattended run will fail
  cleanly (not hang) unless passwordless sudo is configured for the specific
  apt/dnf/pacman commands — `vscodeExtensions` and `fonts` need no elevation and work
  unattended regardless.
- **macOS**: a LaunchAgent (`com.workstation.autoupgrade`), daily at the configured
  time via `StartCalendarInterval`.

Before doing any work, an unattended run checks:

1. The current local time falls inside `[windowStart, windowEnd)`.
2. `skipIfContainersRunning`: if any Docker container is running, the run skips
   entirely, so it never disrupts an active Dev Container session or the shared
   `ai-runtime`.

`workstation doctor` reports the last run time/result for both `WorkstationSetupAutoSync`
and `WorkstationAutoUpgrade` (or their systemd/launchd equivalents), so a broken
background job surfaces automatically instead of requiring manual inspection.

## AI agents

Agents may run `workstation upgrade` directly to refresh tools. Do not enable/disable
the background scheduled task/timer/LaunchAgent without the user's explicit go-ahead —
that changes persistent, unattended, sometimes-elevated behavior on the live machine.
