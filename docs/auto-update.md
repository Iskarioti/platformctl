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
  bootstrap installs, never a blanket whole-system upgrade. On Windows this loop
  covers every package in `windows/10-install-tools.ps1`'s full list (LibreWolf,
  Alacritty, Wireshark, WireGuard, Logi Options+, Microsoft Teams, Outlook, etc.
  included) via `winget upgrade` per package. On macOS/Linux, `scripts/posix/
  upgrade.sh` checks each of those same optional GUI apps is actually installed
  (`dpkg -s`/`rpm -q`/`pacman -Qi`/`brew list --cask`) before including it in the
  upgrade command - `apt-get install --only-upgrade`/`brew upgrade --cask` on a
  package/cask that was never installed errors and fails the whole step, so this
  can't be a static list the way the always-present baseline tools are.

  Two Windows-side edge cases found live (2026-09-13) and handled in
  `windows/10-install-tools.ps1`:
  - **A package can't upgrade its own running process.** If a package
    declares a `ProcessName` (currently just Claude Code, since a
    `workstation upgrade` run is very often an agent session upgrading
    itself), the upgrade is skipped while that process is running - `winget`
    would otherwise fail every time trying to replace its own locked exe.
    Upgrade it yourself when no session is open, or let it self-update.
  - **A package's "newer" version can itself be broken.** Confirmed live,
    repeatedly (2026-09-13/14): Bing Wallpaper's winget manifest reports
    `2.0.0.1` as available but its installer fails with MSI error 1603
    unconditionally (every retry, every `--scope`) - only the older
    `1.1.459` actually installs. When winget reports "the install technology
    is different from the current version installed" (a case the
    post-upgrade check would otherwise silently miss, since the package
    stays present either way), the general-purpose fix is: uninstall, try
    the "newer" version, and if that fails, fall back to reinstalling
    winget's own previous catalog version (**from winget's catalog via
    `winget show --versions`, never the locally-installed version** - Bing
    Wallpaper self-updates independent of winget, so those two can diverge;
    an earlier version of this fix used the locally-installed version as the
    fallback target and it had drifted to something winget's catalog had
    never heard of, leaving the app completely uninstalled with no
    recovery). That general fallback logic stays in the codebase for any
    *other* package that hits this message for real. For Bing Wallpaper
    specifically, since `2.0.0.1` is now confirmed durably broken (not a
    transient issue - it fails identically every single time), a package can
    declare `SkipUpgrade` with an explanation to skip the upgrade attempt
    entirely rather than repeat the same pointless uninstall/reinstall dance
    (which also stops the running app) on every future run for zero gain.
  - **Managed app configuration/state gets reinstated after `packages`
    runs.** A package upgrade or reinstall can silently reset state this
    repo manages - confirmed live: a Bing Wallpaper reinstall leaves it
    installed but not *running*, undoing "always have wallpaper set to Bing
    Wallpaper" until someone notices. `windows/10-install-tools.ps1` itself
    now calls `43-configure-taskbar-appearance.ps1 -NoRestartExplorer`
    (macOS: `platform/macos/configure-appearance.sh` from
    `scripts/posix/upgrade.sh`) at its own tail, unconditionally - moved
    there (not left as a separate step only `workstation upgrade` remembers
    to chain) so this is self-contained for *any* caller: bootstrap, `workstation
    upgrade`, or a standalone re-run of `10-install-tools.ps1` alone. Fully
    idempotent, so a no-op when nothing actually needed restoring, and
    harmless even when something else (bootstrap.ps1's own later step 43)
    also runs the same script again right after.
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
