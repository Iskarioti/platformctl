#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Script = Join-Path $Root "scripts\common\autosync.ps1"
$HiddenRunner = Join-Path $PSScriptRoot "run-hidden.vbs"

# Resolve the real pwsh.exe binary path rather than relying on the bare
# "pwsh.exe" name. When PowerShell resolves through a Store/MSIX App
# Execution Alias (common on machines where PowerShell was installed from
# the Microsoft Store), Task Scheduler's CreateProcess call cannot follow
# that alias reparse point and fails with ERROR_FILE_NOT_FOUND even though
# the same command works fine when typed interactively. Embedding the
# resolved absolute path sidesteps that.
$PwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $PwshCommand) {
    throw "pwsh.exe could not be resolved; cannot install autosync scheduled task."
}
$PwshPath = $PwshCommand.Source

# Uses the ScheduledTasks module rather than schtasks.exe: schtasks.exe's
# /TR value has a hard 261-character limit, and this repo's own path (nested
# under a synced "OneDrive - WIOCC\Documents" folder) plus pwsh.exe's path
# plus the hidden-runner wrapper below routinely exceeds that.
#
# Route through wscript.exe + run-hidden.vbs rather than launching pwsh.exe
# directly - see run-hidden.vbs for why a bare scheduled pwsh.exe task
# flashes a visible console window every run regardless of the task's own
# "Hidden" setting.
$Action = New-ScheduledTaskAction `
    -Execute "wscript.exe" `
    -Argument "//B `"$HiddenRunner`" `"$PwshPath`" -NoLogo -NoProfile -File `"$Script`" -Once"

$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 5) `
    -RepetitionDuration ([TimeSpan]::MaxValue)

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew

Register-ScheduledTask `
    -TaskName "WorkstationSetupAutoSync" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Force |
    Out-Null

Write-Host "Autosync enabled: every 5 minutes (hidden), validate -> apply -> commit -> push current branch."
