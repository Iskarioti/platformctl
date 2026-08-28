#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$WhatIf
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$SourceSettings = Join-Path $Root "windows-terminal\settings.json"

if (-not (Test-Path $SourceSettings)) {
    throw "Windows Terminal settings template was not found: $SourceSettings"
}

# Validate the repository JSON before touching the user's configuration.
Get-Content $SourceSettings -Raw | ConvertFrom-Json | Out-Null

$Candidates = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState"),
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal")
)

$TerminalDir = $null

foreach ($Candidate in $Candidates) {
    if (Test-Path $Candidate) {
        $TerminalDir = $Candidate
        break
    }
}

if (-not $TerminalDir) {
    throw "Windows Terminal settings directory was not found. Start Windows Terminal once, close it, and rerun this script."
}

$TargetSettings = Join-Path $TerminalDir "settings.json"

Write-Host "=== Windows Terminal configuration ===" -ForegroundColor Cyan
Write-Host "Source: $SourceSettings"
Write-Host "Target: $TargetSettings"
Write-Host "Default/only profile: PowerShell 7 {574e775e-4f2a-5b96-ac1e-a2962a402336}"

if ($WhatIf) {
    Write-Host "WhatIf: no changes made."
    exit 0
}

if (Test-Path $TargetSettings) {
    $Backup = "$TargetSettings.backup.$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $TargetSettings $Backup -Force
    Write-Host "Backup: $Backup"
}

Copy-Item $SourceSettings $TargetSettings -Force

# Validate the deployed JSON.
$Deployed = Get-Content $TargetSettings -Raw | ConvertFrom-Json
if ($Deployed.defaultProfile -ne "{574e775e-4f2a-5b96-ac1e-a2962a402336}") {
    throw "Deployed Terminal configuration does not have the expected PowerShell 7 default profile."
}

if ($Deployed.profiles.list.Count -ne 1) {
    throw "Deployed Terminal configuration must expose exactly one explicit profile."
}

Write-Host ""
Write-Host "Windows Terminal configuration installed." -ForegroundColor Green
Write-Host "Close every Windows Terminal window and reopen it to apply all settings."
