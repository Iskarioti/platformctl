#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$NoRestartExplorer
)

$ErrorActionPreference = "Stop"

# Managed Taskbar/theme appearance - the macOS-side equivalent of
# platform/macos/configure-appearance.sh's Dock sizing. Values chosen to
# mirror that script's compact/dark defaults (see docs/desktop-appearance.md
# for the full rationale, including why app *pinning* is deliberately NOT
# automated here).
#
# Idempotent: setting the same registry values again is a no-op.

$AdvancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
$PersonalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

# New-Item -Force on an ALREADY-EXISTING registry key throws "Attempted to
# perform an unauthorized operation" (confirmed live) - both keys exist by
# default on every real Windows install, so only create if genuinely
# missing rather than force-creating unconditionally.
if (-not (Test-Path $AdvancedKey)) { New-Item -Path $AdvancedKey -Force | Out-Null }
if (-not (Test-Path $PersonalizeKey)) { New-Item -Path $PersonalizeKey -Force | Out-Null }

# TaskbarSi: 0 = small icons, 1 = default, 2 = large.
Set-ItemProperty -Path $AdvancedKey -Name "TaskbarSi" -Type DWord -Value 0
# TaskbarAl: 0 = left-aligned (classic), 1 = centered (Windows 11 default).
Set-ItemProperty -Path $AdvancedKey -Name "TaskbarAl" -Type DWord -Value 0

# Dark mode, matching macOS's AppleInterfaceStyle=Dark.
Set-ItemProperty -Path $PersonalizeKey -Name "AppsUseLightTheme" -Type DWord -Value 0
Set-ItemProperty -Path $PersonalizeKey -Name "SystemUsesLightTheme" -Type DWord -Value 0

Write-Host "Taskbar size/alignment and app theme set (small icons, left-aligned, dark)."

if (-not $NoRestartExplorer) {
    Write-Host "Restarting Explorer to apply changes (open File Explorer windows will briefly close/reopen)..."
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
} else {
    Write-Host "Skipped Explorer restart (-NoRestartExplorer) - sign out/in or restart Explorer yourself to see the change."
}

Write-Host ""
Write-Host "NOT automated (Windows 11 has no reliable, unattended taskbar-pinning API" -ForegroundColor Yellow
Write-Host "as of 24H2 - see docs/desktop-appearance.md): pin these manually, in order," -ForegroundColor Yellow
Write-Host "via right-click -> Pin to taskbar:" -ForegroundColor Yellow
Write-Host "  1. File Explorer"
Write-Host "  2. Windows Terminal"
Write-Host "  3. Visual Studio Code"
Write-Host "  4. LibreWolf"
