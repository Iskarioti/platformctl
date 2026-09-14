#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$NoRestartExplorer
)

$ErrorActionPreference = "Stop"

# Ordinary per-user preference values (as opposed to TaskbarDa/HideRecommended-
# Section-style settings, some of which are policy-namespaced or MDM-contested -
# see docs/desktop-appearance.md) share this same idempotent Test-Path-then-
# New-Item-then-Set-ItemProperty shape often enough to warrant one helper,
# rather than repeating the pattern by hand for every new value.
function Set-UserDword {
    param(
        [Parameter(Mandatory)] [string]$Path,
        [Parameter(Mandatory)] [string]$Name,
        [Parameter(Mandatory)] [int]$Value,
        [Parameter(Mandatory)] [string]$Description
    )
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Type DWord -Value $Value -ErrorAction Stop
        Write-Host "[OK]   $Description"
    } catch {
        Write-Warning "[FAIL] $Description : $($_.Exception.Message)"
    }
}

# Managed Taskbar/theme appearance - the macOS-side equivalent of
# platform/macos/configure-appearance.sh's Dock sizing. Values chosen to
# mirror that script's compact/dark defaults (see docs/desktop-appearance.md
# for the full rationale, including why app *pinning* is deliberately NOT
# automated here).
#
# Idempotent: setting the same registry values again is a no-op.

$AdvancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$PersonalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
$SearchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"

# New-Item -Force on an ALREADY-EXISTING registry key throws "Attempted to
# perform an unauthorized operation" (confirmed live) - all three keys exist
# by default on every real Windows install, so only create if genuinely
# missing rather than force-creating unconditionally.
if (-not (Test-Path $AdvancedKey)) { New-Item -Path $AdvancedKey -Force | Out-Null }
if (-not (Test-Path $PersonalizeKey)) { New-Item -Path $PersonalizeKey -Force | Out-Null }
if (-not (Test-Path $SearchKey)) { New-Item -Path $SearchKey -Force | Out-Null }

# TaskbarSi: 0 = small icons, 1 = default, 2 = large.
Set-ItemProperty -Path $AdvancedKey -Name "TaskbarSi" -Type DWord -Value 0
# TaskbarAl: 0 = left-aligned (classic), 1 = centered (Windows 11 default).
Set-ItemProperty -Path $AdvancedKey -Name "TaskbarAl" -Type DWord -Value 1
# TaskbarDa: 0 = Widgets button hidden, 1 = shown. Confirmed (2026-09, live +
# web research + mdmdiagnosticstool.exe) this write returns "Access is denied"
# even via reg.exe directly - blocked by UCPD (a universal Windows 11 security
# component) AND, independently, an active Intune Policy CSP for this device's
# NewsAndInterests policy area (confirmed via its GPBlockingRegKeyPath/
# GPBlockingRegValueName metadata - see docs/desktop-appearance.md). Disabling
# either would be weakening a real security/management control (AGENTS.md
# rule 3), so the registry route stays best-effort/non-fatal.
#
# The settled decision for this workstation (confirmed with Andrew) is instead
# to uninstall the Widgets app outright, which sidesteps both protections -
# no app installed means no Widgets board or button regardless of TaskbarDa's
# value. Idempotent: a no-op if already removed. $widgetsResolved tracks
# whether Widgets ends up actually gone by EITHER mechanism, so the summary
# message doesn't claim an uninstall was attempted when the app was already
# absent, or vice versa.
$widgetsResolved = $false
try {
    Set-ItemProperty -Path $AdvancedKey -Name "TaskbarDa" -Type DWord -Value 0 -ErrorAction Stop
    $widgetsResolved = $true
} catch {
    # Best-effort - the uninstall step below is the real fallback.
}

$widgetsPkg = Get-AppxPackage -Name "*WebExperience*" -ErrorAction SilentlyContinue
if (-not $widgetsPkg) {
    $widgetsResolved = $true
} else {
    try {
        Remove-AppxPackage -Package $widgetsPkg.PackageFullName -ErrorAction Stop
        $widgetsResolved = $true
    } catch {
        Write-Host "Could not uninstall the Widgets app (WebExperience pack): $($_.Exception.Message)" -ForegroundColor Yellow
    }
}
# ShowTaskViewButton: 0 = Task View button hidden, 1 = shown. Same best-effort
# pattern as TaskbarDa above (UCPD does NOT block this one on this machine -
# confirmed live).
$taskViewBlocked = $false
try {
    Set-ItemProperty -Path $AdvancedKey -Name "ShowTaskViewButton" -Type DWord -Value 0 -ErrorAction Stop
} catch {
    $taskViewBlocked = $true
}
# DontUsePowerShellOnWinX: 0 = Win+X menu offers "Windows PowerShell", 1 = "Command Prompt".
# This is the Win+X power-user menu only - independent of Windows Terminal's own
# default profile, which stays pinned to PowerShell 7 per AGENTS.md rule 6.
Set-ItemProperty -Path $AdvancedKey -Name "DontUsePowerShellOnWinX" -Type DWord -Value 0

# SearchboxTaskbarMode: 0 = hidden, 1 = icon only, 2 = search box, 3 = icon + label.
Set-ItemProperty -Path $SearchKey -Name "SearchboxTaskbarMode" -Type DWord -Value 0

# Dark mode, matching macOS's AppleInterfaceStyle=Dark.
Set-ItemProperty -Path $PersonalizeKey -Name "AppsUseLightTheme" -Type DWord -Value 0
Set-ItemProperty -Path $PersonalizeKey -Name "SystemUsesLightTheme" -Type DWord -Value 0

# Start Menu: no Recommended section, All Apps in Category view. Unlike
# ConfigureStartPins/LockedStartLayout (see docs/desktop-appearance.md -
# those get silently ignored or wiped on this machine), these three values
# under the SAME HKCU:\...\Policies\Microsoft\Windows\Explorer key were
# confirmed live to actually take effect and survive an Explorer restart -
# not every value under that key behaves the same way, so don't assume this
# means the earlier-blocked ones would now work too.
$StartPolicyKey = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
$StartKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"
if (-not (Test-Path $StartPolicyKey)) { New-Item -Path $StartPolicyKey -Force | Out-Null }
if (-not (Test-Path $StartKey)) { New-Item -Path $StartKey -Force | Out-Null }

# HideRecommendedSection: 1 = Recommended section removed from Start.
Set-ItemProperty -Path $StartPolicyKey -Name "HideRecommendedSection" -Type DWord -Value 1
# HideCategoryView: 0 = Category view available (and becomes the default);
# 1 would remove it and force Grid - we want it available, so 0.
Set-ItemProperty -Path $StartPolicyKey -Name "HideCategoryView" -Type DWord -Value 0
# AllAppsViewMode: 0 = Category, 1 = Grid, 2 = List. Not a formally documented
# policy (unlike the two above), just the plain per-user preference value -
# still confirmed to work live.
Set-ItemProperty -Path $StartKey -Name "AllAppsViewMode" -Type DWord -Value 0

# Further Start/taskbar/tray decluttering - plain per-user preferences, not the
# policy-namespaced keys above, so no MDM/UCPD contention expected on any of
# these (unlike TaskbarDa/HideRecommendedSection's siblings). Each is
# independently best-effort via Set-UserDword rather than assumed to work
# just because it's not under a Policies\ key.
Set-UserDword -Path $StartKey -Name "ShowRecentList" -Value 0 `
    -Description "Start: Show recently added apps = Off"
Set-UserDword -Path $AdvancedKey -Name "Start_TrackDocs" -Value 0 `
    -Description "Start: Recommended/recent files and Jump Lists = Off"
Set-UserDword -Path $AdvancedKey -Name "Start_IrisRecommendations" -Value 0 `
    -Description "Start: Tips, shortcuts and app recommendations = Off"
Set-UserDword -Path $AdvancedKey -Name "Start_TrackProgs" -Value 0 `
    -Description "Start: Show most used apps = Off"
Set-UserDword -Path $AdvancedKey -Name "Start_AccountNotifications" -Value 0 `
    -Description "Start: Account-related notifications = Off"

# Resume (Windows 11's "pick up where you left off" taskbar feature).
Set-UserDword -Path $AdvancedKey -Name "IsEnabled" -Value 0 `
    -Description "Taskbar: Resume = Off"

# System tray icons for pen/touch/emoji input - harmless to set even on
# hardware without a pen/touchscreen (nothing to show either way then), and
# keeps the tray clean on hardware that does have one.
$TabletTipKey = "HKCU:\Software\Microsoft\TabletTip\1.7"
$PenWorkspaceKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\PenWorkspace"
# 0 = Never, 1 = While typing, 2 = Always.
Set-UserDword -Path $TabletTipKey -Name "EmojiAndMoreIconVisibilityState" -Value 0 `
    -Description "System tray: Emoji and more = Never"
Set-UserDword -Path $PenWorkspaceKey -Name "PenWorkspaceButtonDesiredVisibility" -Value 0 `
    -Description "System tray: Pen Menu = Off"
# 0 = Never, 1 = Always, 2 = When no keyboard is attached.
Set-UserDword -Path $TabletTipKey -Name "TipbandDesiredVisibility" -Value 0 `
    -Description "System tray: Touch keyboard = Never"

Write-Host "Taskbar alignment/search, Win+X menu, and app theme set" -NoNewline
Write-Host " (centered, search hidden, PowerShell on Win+X, dark)."
Write-Host "Start Menu: Recommended section hidden, All Apps set to Category view."
if ($widgetsResolved) {
    Write-Host "Widgets: resolved (app not installed - no board/button regardless of TaskbarDa)."
} else {
    Write-Host "Widgets: registry write blocked AND app uninstall failed - see" -ForegroundColor Yellow
    Write-Host "docs/desktop-appearance.md for the remaining manual alternative (Settings toggle)." -ForegroundColor Yellow
}
if ($taskViewBlocked) {
    Write-Host "Task View button: could not disable (Access is denied) - likely the same" -ForegroundColor Yellow
    Write-Host "UCPD protection as Widgets above." -ForegroundColor Yellow
} else {
    Write-Host "Task View button disabled."
}

# Bing Wallpaper (winget-installed by windows/10-install-tools.ps1) only registers
# itself as a login item (HKCU Run\BingWallpaperDaemon) after its first real launch -
# there's no separate "enable at startup" flag to set instead. Launch it once here if
# it isn't already running so "always have wallpaper set to Bing Wallpaper" actually
# holds after a fresh bootstrap, not just after install.
if (-not (Get-Process -Name "BingWallpaper" -ErrorAction SilentlyContinue)) {
    try {
        Start-Process "BingWallpaper.exe" -ErrorAction Stop
        Write-Host "Launched Bing Wallpaper (first run - it will register itself to start at login)."
    } catch {
        Write-Host "Could not launch Bing Wallpaper automatically - open it once manually from the Start menu." -ForegroundColor Yellow
    }
} else {
    Write-Host "Bing Wallpaper already running."
}

# Alacritty's own MSI-installed Start Menu shortcut launches alacritty.exe
# directly with no way to center it (see scripts/windows/
# launch-alacritty-centered.ps1's header for why that can't just be a config
# value). A per-user Start Menu shortcut of the same name/relative path
# silently shadows the all-users one Alacritty's installer creates (confirmed
# live: Windows Explorer shows only the per-user copy when both exist), so
# creating this one here - pointed at the centering launcher via the same
# wscript.exe/run-hidden.vbs hidden-launch pattern used elsewhere in this repo
# - replaces the vendor shortcut without touching or uninstalling it.
# Idempotent: overwriting an identical .lnk is a no-op.
#
# This does NOT fix a taskbar pin created before this shortcut existed -
# Windows taskbar pins snapshot whatever target the pinned shortcut had at
# pin time, not a live reference. If Alacritty was already pinned to the
# taskbar from an earlier session, unpin it and re-pin from this Start Menu
# entry once to pick up centering.
try {
    $AlacrittyExeForShortcut = "C:\Program Files\Alacritty\alacritty.exe"
    if (Test-Path -LiteralPath $AlacrittyExeForShortcut -PathType Leaf) {
        $CenterLauncher = Join-Path $PSScriptRoot "..\scripts\windows\launch-alacritty-centered.ps1"
        $HiddenRunnerForShortcut = Join-Path $PSScriptRoot "..\scripts\windows\run-hidden.vbs"
        $PwshExe = (Get-Command "pwsh.exe" -ErrorAction SilentlyContinue).Source
        if (-not $PwshExe) { $PwshExe = "pwsh.exe" }

        $ShortcutPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Alacritty.lnk"
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut($ShortcutPath)
        $Shortcut.TargetPath = "wscript.exe"
        $Shortcut.Arguments = "//B `"$HiddenRunnerForShortcut`" `"$PwshExe`" -NoLogo -NoProfile -File `"$CenterLauncher`""
        $Shortcut.WorkingDirectory = $env:USERPROFILE
        $Shortcut.IconLocation = "$AlacrittyExeForShortcut,0"
        $Shortcut.Description = "Alacritty (centered on launch)"
        $Shortcut.Save()
        Write-Host "[OK] Alacritty Start Menu shortcut now launches centered"
    } else {
        Write-Host "[SKIP] Alacritty not installed - centered-launch shortcut not created" -ForegroundColor Yellow
    }
} catch {
    Write-Host "[FAIL] Could not create centered-launch shortcut for Alacritty - $($_.Exception.Message)" -ForegroundColor Red
}

if (-not $NoRestartExplorer) {
    Write-Host "Restarting Explorer to apply changes (open File Explorer windows will briefly close/reopen)..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Skipped Explorer restart (-NoRestartExplorer) - sign out/in or restart Explorer yourself to see the change."
}

# The 4 apps that should end up pinned each need to actually be installed before
# pinning is attempted - check here and flag any that are missing, rather than
# silently telling Andrew to pin something that isn't there yet. Refresh $env:Path
# from the registry first (Machine + User) - a winget install run earlier in THIS
# SAME session (as opposed to bootstrap.ps1's normal pattern of a fresh pwsh.exe
# process per numbered script) only updates the on-disk PATH, not this process's
# already-loaded copy, and Get-Command would otherwise report a just-installed app
# as missing (confirmed live: LibreWolf/Alacritty, installed moments earlier in
# this same shell, initially showed as MISSING until this refresh was added).
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

# PATH/Get-Command alone isn't enough: unlike Alacritty's MSI (which registers
# itself on PATH), LibreWolf's installer - like most browsers - adds neither a
# PATH entry nor an "App Paths" registry key (confirmed live: Get-Command, App
# Paths, and $env:Path all miss it after a real install). Separately, MSIX/UWP
# apps (Teams, Outlook, Bing Wallpaper) expose only a WindowsApps "execution
# alias" - a 0-byte reparse-point stub - and Get-Command was found to resolve
# these unreliably even with the alias directory on PATH (confirmed live: same
# call, same session, worked for one alias and not another with no code
# difference). Known Program Files/WindowsApps locations are checked directly
# via Test-Path instead of trusting Get-Command for any of these.
function Test-AppInstalled([string[]]$CommandNames, [string[]]$KnownPaths = @()) {
    foreach ($Cmd in $CommandNames) {
        if (Get-Command $Cmd -ErrorAction SilentlyContinue) { return $true }
    }
    foreach ($KnownPath in $KnownPaths) {
        if (Test-Path -LiteralPath $KnownPath -PathType Leaf) { return $true }
    }
    return $false
}

$WindowsAppsDir = Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps"

$PinTargets = @(
    @{ Label = "LibreWolf"; Commands = @("librewolf.exe"); KnownPaths = @(
        "C:\Program Files\LibreWolf\librewolf.exe",
        "${env:LOCALAPPDATA}\LibreWolf\librewolf.exe"
    ) }
    @{ Label = "Settings"; Commands = @(); KnownPaths = @() }   # built into Windows, always present
    @{ Label = "Visual Studio Code"; Commands = @("code.cmd", "Code.exe"); KnownPaths = @() }
    @{ Label = "Alacritty"; Commands = @("alacritty.exe"); KnownPaths = @() }
)

# Pinned only when actually installed - unlike $PinTargets above, these are
# genuinely optional (not everyone needs Teams/Outlook), so a missing one is
# silently omitted from the printed list rather than flagged [MISSING].
$ConditionalTaskbarTargets = @(
    @{ Label = "Microsoft Teams"; KnownPaths = @((Join-Path $WindowsAppsDir "ms-teams.exe")) }
    @{ Label = "Outlook";         KnownPaths = @((Join-Path $WindowsAppsDir "olk.exe")) }
)

# Start menu pins - a separate surface from the taskbar (same "no reliable
# unattended pinning API" limitation applies - see docs/desktop-appearance.md).
# This is every "core" baseline app (windows/10-install-tools.ps1's package
# list) that has a genuine Start Menu entry and isn't already on the taskbar
# (LibreWolf/VS Code/Alacritty are taskbar-pinned already, so excluded here;
# pure CLI tools with no Start Menu presence at all - git, jq, GitHub CLI,
# Claude Code, Codex CLI, pixi, Quarto, Pandoc - are excluded for the same
# reason Azure CLI is flagged [NOT PINNABLE] below, they just don't have one).
$StartPinTargets = @(
    @{ Label = "Wireshark"; KnownPaths = @("C:\Program Files\Wireshark\Wireshark.exe") }
    @{ Label = "WireGuard"; KnownPaths = @("C:\Program Files\WireGuard\wireguard.exe") }
    @{ Label = "Outlook";   KnownPaths = @((Join-Path $WindowsAppsDir "olk.exe")) }
    @{ Label = "Microsoft Edge"; KnownPaths = @(
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
    ) }
    @{ Label = "7-Zip"; KnownPaths = @("C:\Program Files\7-Zip\7zFM.exe") }
    @{ Label = "Logi Options+"; KnownPaths = @("C:\Program Files\LogiOptionsPlus\LogiOptionsPlus.exe") }
    @{ Label = "PowerToys"; KnownPaths = @("C:\Program Files\PowerToys\PowerToys.exe") }
    @{ Label = "Windows Terminal"; KnownPaths = @((Join-Path $WindowsAppsDir "wt.exe")) }
    @{ Label = "MiKTeX Console"; KnownPaths = @(
        (Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\MiKTeX\MiKTeX Console.lnk")
    ) }
)

# Azure CLI was explicitly asked for, but it genuinely has no GUI/Start Menu
# entry to pin - confirmed live: no matching .lnk anywhere under either Start
# Menu Programs folder (all-users or per-user), and `az`/`az.cmd` are CLI-only.
# Reported as [NOT PINNABLE] below rather than pinning something that doesn't
# exist or silently dropping the request.

Write-Host ""
Write-Host "NOT automated (see docs/desktop-appearance.md for why):" -ForegroundColor Yellow
Write-Host "  - Taskbar pinning has no reliable unattended API as of Windows 11 24H2." -ForegroundColor Yellow
Write-Host "    First, unpin EVERY currently pinned taskbar icon (right-click ->" -ForegroundColor Yellow
Write-Host "    Unpin from taskbar), including Microsoft Store and any OEM/default" -ForegroundColor Yellow
Write-Host "    pins - then pin only these, in order (right-click -> Pin to taskbar):" -ForegroundColor Yellow
foreach ($Target in $PinTargets) {
    $Installed = ($Target.Commands.Count -eq 0) -or (Test-AppInstalled $Target.Commands $Target.KnownPaths)
    if ($Installed) {
        Write-Host "      [ready]   $($Target.Label)"
    } else {
        Write-Host "      [MISSING] $($Target.Label) - not installed yet, run windows\10-install-tools.ps1 first" -ForegroundColor Yellow
    }
}
foreach ($Target in $ConditionalTaskbarTargets) {
    if (Test-AppInstalled @() $Target.KnownPaths) {
        Write-Host "      [ready, optional] $($Target.Label) - pin too if you want it on the taskbar"
    }
}
Write-Host "  - Start Menu pinning has the same limitation. First, unpin EVERY" -ForegroundColor Yellow
Write-Host "    currently pinned Start Menu tile (right-click -> Unpin from Start) -" -ForegroundColor Yellow
Write-Host "    a workstation setup ends with ONLY the apps this script lists pinned" -ForegroundColor Yellow
Write-Host "    on Start and taskbar, nothing else left over from OEM/Store defaults" -ForegroundColor Yellow
Write-Host "    or earlier manual pins - then pin only these (right-click -> Pin to Start):" -ForegroundColor Yellow
foreach ($Target in $StartPinTargets) {
    if (Test-AppInstalled @() $Target.KnownPaths) {
        Write-Host "      [ready]   $($Target.Label)"
    } else {
        Write-Host "      [MISSING] $($Target.Label) - not installed yet, run windows\10-install-tools.ps1 first" -ForegroundColor Yellow
    }
}
Write-Host "      [NOT PINNABLE] Azure CLI - CLI-only, no Start Menu shortcut exists" -ForegroundColor Yellow
Write-Host "  - Night Light (sunset-to-sunrise) is stored as an opaque binary blob, not" -ForegroundColor Yellow
Write-Host "    plain registry flags - enable it manually once via Settings ->" -ForegroundColor Yellow
Write-Host "    System -> Display -> Night light -> Schedule night light -> Sunset to" -ForegroundColor Yellow
Write-Host "    sunrise. It then persists on its own; no re-configuration needed after." -ForegroundColor Yellow
