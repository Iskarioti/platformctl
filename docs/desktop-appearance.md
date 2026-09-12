# Desktop Appearance (Dock / Taskbar / Wallpaper)

A "fully fledged workstation" isn't just tools and dev-services - this covers the
Dock (macOS) and Taskbar (Windows) appearance, pinned apps, and desktop wallpaper.
Reviewed against Andrew's previous personal dotfiles
(`github.com/Iskarioti/.dotfiles`, `nix/darwin/flake.nix`'s `system.defaults` block)
and reimplemented here as plain shell/PowerShell since this repo is imperative, not
Nix-based.

## macOS

`platform/macos/configure-appearance.sh`, run from `platform/macos/bootstrap.sh`
(best-effort - a bootstrap run doesn't fail over a cosmetic step):

- Dock: `tilesize=32`, `largesize=100` (magnified), `autohide=true`,
  `magnification=true`, `mineffect=genie`, `show-recents=false`.
- Dock pinned apps, via [dockutil](https://github.com/keimoon/dockutil)
  (`brew install dockutil` - plain `defaults write` can't reliably express Dock
  `persistent-apps` entries without hand-built CFURL bookmark data): Finder,
  LibreWolf, Visual Studio Code, Terminal, Mail, Calendar, in that order.
- Finder: column view (`FXPreferredViewStyle=clmv`).
- Global: all file extensions shown, Dark mode, 24-hour time, fast key repeat,
  screenshots saved to `~/Downloads`, guest login disabled (hardening, not just
  cosmetic).
- Wallpaper: [Bing Wallpaper](https://formulae.brew.sh/cask/bingpaper) via the
  `bingpaper` Homebrew cask - **not** the `bing-wallpaper` cask, which is Intel-only
  and needs Rosetta 2 on Apple Silicon (confirmed via its formula page). One manual
  step remains: open it once after install so it can register itself as a login
  item - this isn't scriptable without OS-level Accessibility permissions for UI
  scripting, which this repo won't request just for a wallpaper app.

**Not tested on real hardware** - this session has no macOS machine available. The
script is syntax-checked (`bash -n`) and each `defaults write` domain/key matches
Apple's documented behavior and the equivalent nix-darwin option it was ported from,
but has not been run for real. Re-verify on an actual Mac before trusting it blindly.

## Windows

`windows/43-configure-taskbar-appearance.ps1`, run from
`platform/windows/bootstrap.ps1` between `42-configure-windows-terminal.ps1` and
`45-shell-experience.ps1`:

- Taskbar size/alignment via `HKCU:\Software\Microsoft\Windows\CurrentVersion\
  Explorer\Advanced`: `TaskbarSi=0` (small icons, matching the Dock's compact
  32px tiles) and `TaskbarAl=0` (left-aligned, not Windows 11's centered default).
- Dark mode via `HKCU:\...\Themes\Personalize`: `AppsUseLightTheme=0`,
  `SystemUsesLightTheme=0`.
- Restarts Explorer to apply immediately (`-NoRestartExplorer` skips this - open
  File Explorer windows briefly close/reopen otherwise).
- Wallpaper: `Microsoft.BingWallpaper` via winget (`windows/10-install-tools.ps1`)
  - Microsoft's own official app, silently installable, no caveats.

**Verified live** on this machine: `New-Item -Force` on an *already-existing*
registry key threw `Attempted to perform an unauthorized operation` (not a policy
block - confirmed by then running the same `Set-ItemProperty` directly, which
succeeded immediately) - fixed by only creating the key when `Test-Path` says it's
actually missing. After the fix, a real run set all four registry values
(confirmed via `Get-ItemProperty`) and restarted Explorer cleanly.

### Taskbar pinning is intentionally NOT automated

Unlike the Dock, scripting *which apps are pinned* to the Windows 11 taskbar has no
reliable, unattended path as of 24H2:

- The old `LayoutModification.xml` / `Export-StartLayout` approach was broken by
  Windows updates starting ~2023 and locked down further by KB5058411 (May 2025) -
  it now only works under Group Policy/Intune (kiosk or MDM-managed devices), not
  a plain script on an unmanaged personal machine.
- The workarounds that exist (copying the `TaskBand` registry key or `Start2.bin`
  from a manually-configured reference profile) are unsupported and liable to
  break on the next Windows feature update - not something worth wiring into this
  repo's automation.

Pin these manually instead (right-click an open app or Start Menu entry ->
**Pin to taskbar**), in order:

1. File Explorer
2. Windows Terminal
3. Visual Studio Code
4. LibreWolf

If Microsoft ever ships a real, non-MDM taskbar-pinning API again, revisit this.
