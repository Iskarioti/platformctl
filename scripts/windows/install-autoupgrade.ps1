#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Script = Join-Path $Root "scripts\common\upgrade.ps1"
$Config = Get-Content (Join-Path $Root "workstation.json") -Raw | ConvertFrom-Json

if (-not $Config.autoUpdate -or -not $Config.autoUpdate.enabled) {
    Write-Host "autoUpdate.enabled is false in workstation.json; autoupgrade task not installed."
    exit 0
}

$WindowStart = if ($Config.autoUpdate.schedule.windowStart) {
    $Config.autoUpdate.schedule.windowStart
} else {
    "22:00"
}

# Resolve the real pwsh.exe binary path rather than relying on the bare
# "pwsh.exe" name; see scripts/windows/install-autosync.ps1 for why (App
# Execution Alias resolution fails inside Task Scheduler's CreateProcess).
$PwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $PwshCommand) {
    throw "pwsh.exe could not be resolved; cannot install autoupgrade scheduled task."
}
$PwshPath = $PwshCommand.Source

$Action = New-ScheduledTaskAction `
    -Execute $PwshPath `
    -Argument "-NoLogo -NoProfile -File `"$Script`" -Unattended"

$Trigger = New-ScheduledTaskTrigger -Daily -At $WindowStart

# Packages upgrade (winget) requires elevation, matching the
# #Requires -RunAsAdministrator on windows/10-install-tools.ps1. Windows
# Task Scheduler runs a "highest privileges" task for an administrator
# account silently, without an interactive UAC prompt.
$Principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -RunLevel Highest `
    -LogonType Interactive

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -DontStopOnIdleEnd `
    -ExecutionTimeLimit (New-TimeSpan -Hours 2)

Register-ScheduledTask `
    -TaskName "WorkstationAutoUpgrade" `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force |
    Out-Null

Write-Host "Autoupgrade enabled: daily at $WindowStart (elevated), gated by workstation.json autoUpdate settings."
