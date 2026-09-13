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
- Additional apps (`platform/macos/bootstrap.sh`'s cask list): `logi-options+`
  (Logi Options+ - manages Logitech mice/keyboards), `wireshark-app` (the GUI
  cask - plain `wireshark` is the CLI-only formula, not what's wanted here),
  `wireguard`, `microsoft-teams` (requires macOS 14+), `microsoft-outlook`.

**Not tested on real hardware** - this session has no macOS machine available. The
script is syntax-checked (`bash -n`) and each `defaults write` domain/key matches
Apple's documented behavior and the equivalent nix-darwin option it was ported from,
but has not been run for real; the cask names above are confirmed via
formulae.brew.sh, not live-installed. Re-verify on an actual Mac before trusting it
blindly.

## Linux

Unlike macOS/Windows, this repo doesn't manage a native Linux desktop environment
(WSL has no GUI of its own - see `docs/architecture.md`), so there's no Dock/taskbar
equivalent here. What IS installed, best-effort, from `platform/linux/bootstrap.sh`
(useful with any display - native Linux desktop, or WSLg on Windows 11's WSL - same
as the existing `alacritty`/`librewolf` GUI installs):

- `platform/linux/install-solaar.sh`: [Solaar](https://pwr-solaar.github.io/Solaar/)
  (apt/dnf/pacman) - **not** Logi Options+ itself, which Logitech has never shipped
  a Linux client for. Solaar is the community-standard replacement for managing
  Logitech mice/keyboards on Linux (battery, DPI, button remapping) - a different
  app serving the same need, not a port.
- `platform/linux/install-wireshark.sh`: `wireshark` (apt/dnf) / `wireshark-qt`
  (pacman - Arch's GUI package name). Deliberately does NOT preseed the
  `wireshark-common/install-setuid` debconf answer to `true` - the safer default
  (capture requires `sudo` or the `wireshark` group) is left as-is rather than
  broadened unattended, per AGENTS.md rule 3.
- `platform/linux/install-wireguard.sh`: `wireguard` (apt) / `wireguard-tools`
  (dnf/pacman) - CLI/headless, no display needed, so it isn't gated on GUI
  availability the way the other two are.
- **Microsoft Teams and Outlook are not installed on Linux at all** - Teams'
  Linux client was discontinued in 2022 and Outlook has never shipped one; both
  are web-app only (teams.microsoft.com / outlook.office.com) on this platform.
  Deliberately not faked via an Electron/Flatpak wrapper of the web app.

## Windows

`windows/43-configure-taskbar-appearance.ps1`, run from
`platform/windows/bootstrap.ps1` between `42-configure-windows-terminal.ps1` and
`45-shell-experience.ps1`:

- Taskbar size/alignment via `HKCU:\Software\Microsoft\Windows\CurrentVersion\
  Explorer\Advanced`: `TaskbarSi=0` (small icons, matching the Dock's compact
  32px tiles) and `TaskbarAl=1` (centered - Windows 11's default alignment).
- Widgets: `TaskbarDa=0` is attempted first (same `Advanced` key,
  best-effort, wrapped in try/catch) but fails `Access is denied` even via
  `reg.exe` directly - blocked by **UCPD** (a universal Windows 11 security
  component) and, independently, an **active Intune Policy CSP** for this
  device's `NewsAndInterests` policy area (see "Widgets: what actually
  works" below for how that was confirmed precisely, not just inferred).
  **The settled decision for this workstation is to uninstall the Widgets
  app outright** instead of leaving this as a manual step -
  `43-configure-taskbar-appearance.ps1` now does this automatically
  (`Get-AppxPackage -Name "*WebExperience*" | Remove-AppxPackage`,
  idempotent - a no-op if already removed), which sidesteps both
  protections entirely: no app installed means no Widgets board or button
  regardless of `TaskbarDa`'s value. Confirmed live (2026-09-13): removed,
  Explorer restarted, Andrew confirmed the icon is gone.
- Task View button hidden: `ShowTaskViewButton=0` (same `Advanced` key),
  same best-effort try/catch pattern as Widgets - UCPD does NOT protect this
  value on this machine: confirmed live via `Get-ItemProperty` that it applies
  cleanly, unlike `TaskbarDa`.
- Search hidden: `SearchboxTaskbarMode=0` under `HKCU:\...\CurrentVersion\Search`
  (0 = hidden entirely, not just icon-only).
- Win+X power-user menu offers "Windows PowerShell" (not "Command Prompt"):
  `DontUsePowerShellOnWinX=0`, same `Advanced` key. This is independent of
  Windows Terminal's own default shell profile, which stays PowerShell 7 per
  AGENTS.md rule 6 - the two settings don't conflict, they govern different UI
  surfaces (the Win+X menu vs. Windows Terminal's profile list).
- Dark mode via `HKCU:\...\Themes\Personalize`: `AppsUseLightTheme=0`,
  `SystemUsesLightTheme=0`.
- Start Menu: no Recommended section, All Apps in Category view -
  `HideRecommendedSection=1` and `HideCategoryView=0` under `HKCU:\Software\
  Policies\Microsoft\Windows\Explorer` (the real, Microsoft-documented Start
  Menu policies - "Remove Recommended section from Start Menu" and the
  Category-view policy), plus `AllAppsViewMode=0` under `HKCU:\Software\
  Microsoft\Windows\CurrentVersion\Start` (an undocumented but confirmed-
  working per-user preference, not a formal policy). **Confirmed live
  (2026-09-13) that these three specifically DO take effect and survive an
  Explorer restart** - unlike `ConfigureStartPins`/`LockedStartLayout` under
  that very same `Policies\Explorer` key, which get silently ignored or
  wiped on this machine (see the pinning section below). Not every value
  under a policy key behaves the same way; each needs its own live test,
  not an assumption based on a sibling value's result.
- Further Start/taskbar/tray decluttering - all plain per-user preferences
  (not policy-namespaced, so no MDM/UCPD contention expected, and none
  observed): `ShowRecentList=0` (Start's "recently added apps") under
  `HKCU:\...\CurrentVersion\Start`; `Start_TrackDocs=0` (recommended/recent
  files + Jump Lists), `Start_IrisRecommendations=0` (tips/shortcuts/app
  recommendations), `Start_TrackProgs=0` (most-used apps),
  `Start_AccountNotifications=0`, and `IsEnabled=0` (the "Resume" taskbar
  feature) all under the same `Advanced` key as `TaskbarDa`; plus three
  system-tray icon settings - `EmojiAndMoreIconVisibilityState=0` and
  `TipbandDesiredVisibility=0` under `HKCU:\Software\Microsoft\TabletTip\1.7`
  (emoji panel and touch keyboard icons, `0`/`1`/`2` = Never/While
  typing-or-Always/Always-or-When-no-keyboard depending on the setting), and
  `PenWorkspaceButtonDesiredVisibility=0` under `HKCU:\...\CurrentVersion\
  PenWorkspace` (pen menu icon) - harmless to set even without a
  pen/touchscreen. Applied via a small `Set-UserDword` helper (idempotent
  Test-Path/New-Item/Set-ItemProperty, try/catch, `[OK]`/`[FAIL]` output)
  rather than repeating the same four-line pattern by hand for each one.
  All 9 confirmed live (2026-09-13) via direct registry read after a real
  run - every one applied cleanly, no failures.
- Restarts Explorer to apply immediately (`-NoRestartExplorer` skips this - open
  File Explorer windows briefly close/reopen otherwise).
- Wallpaper: `Microsoft.BingWallpaper` via winget (`windows/10-install-tools.ps1`).
  It only registers itself as a login item (`HKCU:\...\Run\BingWallpaperDaemon`)
  after its first real launch - there's no separate registry flag for "start at
  login" to set instead - so `43-configure-taskbar-appearance.ps1` launches it
  once (`BingWallpaper.exe`, its App Execution Alias in `%LOCALAPPDATA%\Microsoft\
  WindowsApps`) if it isn't already running, matching macOS's equivalent
  first-launch caveat for `bingpaper`.
- Additional apps (`windows/10-install-tools.ps1`'s winget package list):
  `Logitech.OptionsPlus` (Logi Options+), `WireGuard.WireGuard`,
  `Microsoft.Teams` (the current "new Teams" client, not the deprecated
  `Microsoft.Teams.Classic`), `Microsoft.Outlook` (the standalone "Outlook for
  Windows" app, not bundled Office). All 5 (Wireshark included, already
  present) confirmed already installed on this machine via `winget list`.

**Verified live** on this machine: `New-Item -Force` on an *already-existing*
registry key threw `Attempted to perform an unauthorized operation` (not a policy
block - confirmed by then running the same `Set-ItemProperty` directly, which
succeeded immediately) - fixed by only creating the key when `Test-Path` says it's
actually missing. Every registry value above (except `TaskbarDa`, see below) and
the Bing Wallpaper launch step have been confirmed via `Get-ItemProperty`/
`Get-Process` on this real machine (`SearchboxTaskbarMode` was already `0` here
from a prior manual change; `BingWallpaperDaemon` was already registered and the
process already running, confirming the self-registration behavior described
above).

### Pinning policy: a workstation setup ends with an explicit-only Start Menu and taskbar

Standing rule (confirmed with Andrew 2026-09-13): **a workstation setup unpins
everything already on both the Start Menu and the taskbar first, then pins only
the apps this doc/script explicitly lists - nothing else stays pinned**, no
OEM/Store defaults, no leftovers from earlier manual pinning. Neither surface has
a reliable unattended pinning *or* unpinning API (see below), so this stays a
documented manual procedure, not something `43-configure-taskbar-appearance.ps1`
can enforce by itself - but it IS the intended end state every time this repo's
Windows setup runs, not a one-time preference.

### Taskbar pinning (and unpinning) is intentionally NOT automated

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
- Unpinning an existing app (e.g. Microsoft Store) goes through the same
  unsupported pinned-items mechanism as pinning a new one, so it isn't automated
  either, for the same reason. The Start Menu's pinned-tiles list is a separate
  but equally unsupported mechanism - same limitation, same manual-only answer.
- **Live-tested (2026-09-13), not just researched**: the classic
  `Shell.Application` COM automation (`$folder.ParseName(...).Verbs()`) still
  works in general on this machine (confirmed: its "Copy" verb's `.DoIt()`
  succeeds) - but the taskbar has **no "Pin to taskbar" verb at all** in the
  returned verb list any more (only "Pin to Start" appears), and calling
  `.DoIt()` on that Start verb fails with `Access is denied (0x80070005
  E_ACCESSDENIED)` specifically - COM automation works, this one action is
  deliberately blocked, the same class of anti-automation protection as
  UCPD blocking the `TaskbarDa` registry write. This is why the script can
  only print instructions, never do the pinning itself, no matter how the
  request is phrased - it isn't unimplemented, it's blocked by Windows.
- **Also live-tested (2026-09-13) and ruled out**: the *local-policy*
  mechanism (`HKCU:\Software\Policies\Microsoft\Windows\Explorer`'s
  `ConfigureStartPins`/`ConfigureStartPinsJSON` for Start, `LockedStartLayout`/
  `StartLayoutFile` for the taskbar - real, Microsoft-documented settings,
  normally applied via Group Policy/Intune but in principle just registry
  values anyone could write locally). Tested directly, not assumed:
  - **Taskbar** (`LockedStartLayout`+`StartLayoutFile`): the values were
    silently **wiped from the registry by Windows itself** after Explorer
    processed them - an active rejection, not a silent no-op.
  - **Start Menu** (`ConfigureStartPins`+`ConfigureStartPinsJSON`): the
    values persist in the registry (not rejected outright), but three
    separate follow-up tests (different AppID formats, `applyOnce: true`
    and `false`, a fresh JSON path each time) produced **no visible change**
    to the actual pinned tiles. An initial 2-app test appeared to work, but
    was almost certainly a false positive - Edge and File Explorer are
    commonly pre-pinned by default, and the baseline wasn't checked before
    that first test ran, a real gap in the test methodology worth
    remembering. All controlled tests after checking for that variable
    showed no effect.
  - **Conclusion**: this mechanism is real and Microsoft-documented, but on
    this machine it only takes effect under genuine Group Policy/MDM
    management, not from a plain local registry write - consistent with
    (and now more rigorously confirmed than) the original research finding.
    All test registry values and scratch files were cleaned up afterward;
    nothing from this experiment was left in place.

The correct manual sequence, in order:

1. **Install first**: all 4 target apps must actually be installed before pinning
   any of them - `43-configure-taskbar-appearance.ps1` checks this at the end of
   its run and prints `[ready]`/`[MISSING]` per app so a missing one is never
   silently skipped over. Run `windows\10-install-tools.ps1` first if anything is
   flagged missing (all 4 - `Microsoft.VisualStudioCode`, `LibreWolf.LibreWolf`,
   `Alacritty.Alacritty`, plus the built-in Settings app - are winget-installed
   there). LibreWolf and Alacritty were both listed in that script but not
   actually installed on this machine until this was checked (2026-09-13) -
   being *in the package list* isn't the same as being *installed*; always
   verify, don't assume a past bootstrap run actually completed every package.
2. **Unpin everything already pinned first** (right-click each icon -> **Unpin
   from taskbar**), Microsoft Store included - starting from a clean taskbar
   avoids ending up with the 4 target apps plus whatever OEM/default pins were
   already there.
3. **Then pin only these 4, in order** (right-click an open app or Start Menu
   entry -> **Pin to taskbar**): LibreWolf, Settings, Visual Studio Code,
   Alacritty.
4. **Optionally, also pin Microsoft Teams and Outlook to the taskbar** - unlike
   the 4 above, these are only pinned *when actually installed*, since not
   every machine needs them. `43-configure-taskbar-appearance.ps1` checks both
   (via their WindowsApps execution-alias paths, `ms-teams.exe`/`olk.exe` under
   `%LOCALAPPDATA%\Microsoft\WindowsApps`) and prints them as
   `[ready, optional]` only when present - a missing one is silently omitted,
   never flagged `[MISSING]` the way the 4 required apps are.
5. **Unpin every currently pinned Start Menu tile too** (right-click -> **Unpin
   from Start**) - same clean-slate rule as the taskbar (see above).
6. **Then pin these to the Start Menu** (right-click -> **Pin to Start**):
   Wireshark, WireGuard, Outlook, Microsoft Edge, 7-Zip, Logi Options+,
   PowerToys, Windows Terminal, MiKTeX Console - checked the same
   `[ready]`/`[MISSING]` way as the taskbar's required 4. This is every "core"
   baseline app (`windows/10-install-tools.ps1`'s package list) with a genuine
   Start Menu entry that isn't already taskbar-pinned; pure CLI tools with no
   Start Menu presence at all (git, jq, GitHub CLI, Claude Code, Codex CLI,
   pixi, Quarto, Pandoc) are excluded for the same reason as Azure CLI below -
   there's nothing to pin.
7. **Azure CLI was asked for but genuinely can't be pinned to Start**:
   confirmed live - no `.lnk` shortcut exists anywhere under either Start Menu
   Programs folder (all-users or per-user) for it, and `az`/`az.cmd` are
   CLI-only with no GUI entry point. The script reports this as
   `[NOT PINNABLE]` rather than silently dropping the request or inventing a
   fake pin target.

If Microsoft ever ships a real, non-MDM taskbar-pinning API again, revisit this.

**Detection gotchas found building the install-check logic** (both fixed in
`43-configure-taskbar-appearance.ps1`): (1) a winget install run in the SAME
PowerShell session as the check doesn't update that process's already-loaded
`$env:Path` (only the on-disk registry value) - the script now refreshes
`$env:Path` from `[System.Environment]::GetEnvironmentVariable(..., "Machine"/
"User")` before checking. Not an issue for `bootstrap.ps1`'s normal flow (each
numbered script is a fresh `pwsh.exe` process). (2) Some installers (LibreWolf,
like most browsers) register neither a PATH entry nor an "App Paths" registry
key, and MSIX/UWP apps (Teams, Outlook) expose only a WindowsApps "execution
alias" that `Get-Command` was found to resolve unreliably even with the alias
directory on PATH (confirmed live: the exact same call worked for one alias and
not another). Known install-path `Test-Path` checks are used instead of
`Get-Command`/PATH for every app this script checks - more reliable, if more
verbose to maintain.

### Widgets: what actually works

Since UCPD (and, as confirmed below, an active Intune Policy CSP) both block the
registry route entirely, disabling Widgets for real needs one of two supported,
Microsoft-documented paths:

1. **Settings app toggle** (least disruptive, not wired into the script -
   requires an interactive UI, nothing to automate): Settings -> Personalization
   -> Taskbar -> turn off **Widgets**. Always works, no admin rights needed,
   purely per-user.
2. **Uninstall the Widgets app entirely**: `Get-AppxPackage *WebExperience* |
   Remove-AppxPackage` (`winget uninstall --id
   MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy` also works but needs the
   exact MSIX-qualified ID - the plain package ID alone returns "No installed
   package found"). Removes the Widgets icon *and* its Settings-app entry
   completely; reversible by reinstalling "Windows Web Experience Pack" from the
   Microsoft Store. A Windows cumulative update can reinstall this package, so
   it may need repeating occasionally - **wired into
   `43-configure-taskbar-appearance.ps1`** (idempotent: uninstalls it again if
   a Windows Update silently brought it back, no-ops if already absent), so
   "occasionally" is handled by the next real run of this script rather than
   needing to be remembered.

A third path, the Local Group Policy toggle (`gpedit.msc` -> Computer
Configuration -> Administrative Templates -> Windows Components -> Widgets ->
"Allow widgets" -> Disabled, which resolves to `HKLM:\SOFTWARE\Policies\
Microsoft\Dsh\AllowNewsAndInterests=0`), was tested live on this machine
(2026-09-13) and **also confirmed blocked** - writing `AllowNewsAndInterests`
into that key, via `Set-ItemProperty`, `New-ItemProperty`, and `reg.exe`
directly, all three fail `Access is denied`, despite `Get-Acl` showing
`BUILTIN\Administrators: FullControl` on the key.

**Root cause identified precisely (2026-09-13), not just inferred from the
symptom.** Collected this device's actual MDM diagnostic state rather than
guessing further:

```powershell
dsregcmd /status                                          # Entra/MDM enrollment state
gpresult /h "$env:TEMP\GPResult.html"                      # resultant Group Policy (traditional GP)
mdmdiagnosticstool.exe -area "DeviceEnrollment;DeviceProvisioning;Autopilot" `
    -zip "<a non-shared temp path>\MDMDiagReport.zip"      # MDM Policy CSP state
```

Findings:
- `dsregcmd /status`: `AzureAdJoined: YES`, `EnterpriseJoined: NO`,
  `DomainJoined: NO` - this device has **no traditional Active Directory
  domain or Group Policy source at all**, only Entra ID + Intune MDM
  enrollment (`DisplayNameUpdated: Managed by MDM` appears literally in the
  output).
- `gpresult /h`: **zero Applied GPOs**, both Computer and User ("No settings
  defined") - conclusively rules out traditional Group Policy as the cause of
  anything observed here. Whatever is enforcing these values, it isn't GP.
- `mdmdiagnosticstool.exe`'s `MDMDiagReport.xml` contains the actual answer,
  in Windows's own Policy CSP metadata:
  ```xml
  <PolicyAreaName>NewsAndInterests</PolicyAreaName>
  <PolicyName>AllowNewsAndInterests</PolicyName>
  <GPBlockingRegKeyPath>SOFTWARE\Policies\Microsoft\Dsh</GPBlockingRegKeyPath>
  <GPBlockingRegValueName>AllowNewsAndInterests</GPBlockingRegValueName>
  <value>1</value>
  ```
  (and the same `GPBlockingRegKeyPath`/`GPBlockingRegValueName` pattern for
  `DisableWidgetsBoard`, `DisableWidgetsOnLockScreen`, and separately for the
  taskbar's `LockedStartLayout` under the `Start` policy area). This is
  Microsoft's own documented mechanism: when an MDM Policy CSP configuration
  profile is active for a given area, Windows tracks the equivalent local/GP
  registry location as "GP-blocking" and actively prevents writing it
  directly - MDM wins over any equivalent local configuration by design, not
  by an incidental permissions quirk. **`value: 1` for `AllowNewsAndInterests`
  means WIOCC's own Intune tenant has deliberately configured Widgets as
  *allowed*** - this isn't a platform default being defended, it's an actual
  organizational policy choice being enforced.
- By contrast, `HideRecommendedSection`/`HideCategoryView` (which DID work,
  see above) have no `GPBlockingRegKeyPath` entry anywhere in the same
  report - confirming why: no Intune configuration profile targets those
  specific CSP areas, so the local write goes through cleanly. `TaskbarDa`
  itself remains UCPD's separate, narrower protection (confirmed earlier),
  not part of this MDM mechanism - two independent protections, over
  different but overlapping registry surfaces, is what made this look like
  one broad "anti-tamper layer" before this diagnostic pass.

This machine's diagnostic dump was written to a temp/scratch location and
deleted immediately after extracting the relevant findings above - it
contains certificate thumbprints, hardware hashes, and other
device-identifying data that shouldn't persist anywhere, let alone a shared
location. Per AGENTS.md rule 3, none of this was used to attempt a bypass
(no ACL/ownership changes, no disabling of whatever enforces MDM-wins-over-
local) - both remaining options above (Settings toggle, uninstalling the
Widgets app) stay the actual answer, and are the two paths Microsoft itself
documents as unaffected by this MDM-vs-local precedence.

**Automation rule going forward**: attempt the supported local configuration
once; if it's denied outright or silently reverted after being written,
stop - don't take ownership, change ACLs, or otherwise try to defeat
whatever is enforcing it. Every script in this repo already follows this
(plain `try`/`catch` around each write, report-and-continue, nothing more) -
this session's diagnostic pass didn't change that behavior, it just replaced
a correct-but-vague conclusion ("something blocks this") with the precise,
Microsoft-documented mechanism actually responsible.

### Enforcement (drift detection)

`workstation enforce` (Windows side, `scripts/common/enforce.ps1`) checks every
setting above against its desired value on every run - not just once at bootstrap -
so a Windows feature update or a manual change that resets one is caught, not
silently lost. `workstation enforce --repair` re-runs
`windows/43-configure-taskbar-appearance.ps1` first, then reports the (now
repaired) state. Widgets (`TaskbarDa`) is the one exception: a mismatch there is
reported as a WARN, never a FAIL, because it's blocked by UCPD (see above), not
fixable drift - `enforce` doesn't try to disable UCPD to force it through, per
AGENTS.md rule 3.

### Night Light is intentionally NOT automated

"Night color, sunset to sunrise" (Settings -> System -> Display -> Night light) is
stored as an opaque serialized binary blob, not plain DWORD flags, under
`HKCU:\Software\Microsoft\Windows\CurrentVersion\CloudStore\Store\DefaultAccount\
Current\default$windows.data.bluelightreduction.bluelightreductionstate\...` (on/off
state) and a parallel `...bluelightreduction.settings\...` key (the sunset-to-sunrise
schedule). **Verified live** on this machine via `Format-Hex` against the real key -
it's a versioned binary structure (observed starting `43 42 01 00 0A 02 01 00 ...`),
not a documented, stable format safe to hand-construct and write blind. This is the
same class of problem as taskbar pinning above (an undocumented internal format with
no supported API), so it's handled the same way: enable it manually once via
Settings, and it persists on its own from then on - no repeated configuration
needed, so there's little value in automating it even if the format were reverse-
engineered.

### Bing Wallpaper's own in-app toggles are intentionally NOT automated

Bing Wallpaper's widget has its own settings (AI images, "Top right" position,
Visual Search, "Desktop click opens Bing") beyond what this repo configures
(daily wallpaper rotation itself, and launching it - see above). Investigated
live (2026-09-13) rather than guessed at:

- `HKCU:\Software\Microsoft\BingWallpaperApp\OverrideWallpaper` - a
  documented setting for an **older, classic Win32 build** of Bing Wallpaper -
  **does not exist at all** on the version winget actually installs on this
  machine (`1.1.463.0`, confirmed via `Test-Path`/`Get-ItemProperty`). That
  build is MSIX-packaged (depends on `Microsoft.WindowsAppRuntime`) and uses a
  completely different storage model - the registry path from an older
  version doesn't carry over.
- The real per-user config surface is `%LOCALAPPDATA%\Packages\
  Microsoft.BingWallpaper_8wekyb3d8bbwe\LocalState\server_config.json` - but
  this is a **server-synced feature-flag/experiment cache**, not a local
  preference file: it contains MSIX download URLs, A/B-test bucket
  assignments (`ExpAssignmentContext`), and promo-banner configuration
  alongside flag-shaped keys like `TopRightIconEnabled`/
  `VisualSearchGlowEffectEnabled` that look relevant but represent which
  features are available for this build/experiment cohort, not whether the
  user personally turned them on or off. Editing it would likely be silently
  overwritten on the app's next sync with Microsoft's servers.
- The widget's actual UI is rendered inside an **embedded Chromium WebView2
  instance** (confirmed live - a full Chrome-profile folder structure under
  `LocalState\BingWallpaper_Widget\1001\EBWebView\Default\`, including a
  `Local Storage\leveldb\` directory). Per-user toggle state almost certainly
  lives there, in Chromium's LevelDB key-value log format - not registry, not
  a plain JSON file. This is a materially different, harder automation
  problem than every other setting in this document: no PowerShell-native way
  to read or write a LevelDB store reliably, and no supported alternative
  (WebView2's DevTools protocol could read/write it live, but that's a much
  larger automation surface for 4 cosmetic wallpaper-app toggles).

**Decision (confirmed with Andrew): left as manual, one-time settings** - set
them once via the widget's own settings gear, same category as taskbar
pinning and Night Light above. Not worth LevelDB parsing or DevTools
automation for this.
