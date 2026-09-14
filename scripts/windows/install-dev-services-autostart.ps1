#Requires -Version 7.0
param(
    # ValueFromRemainingArguments: this script runs as a separate pwsh.exe
    # process (invoked via -File from services-autostart-control.ps1), and a
    # plain array bound to a named -Services parameter does not survive that
    # process boundary reliably - only the first element arrives. Splatting
    # the caller's array positionally (@Services, no -Services flag) into a
    # remaining-arguments parameter here is what actually works, confirmed by
    # a real failed run that silently installed a task for "redis" only.
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Services = @("redis", "redisinsight")
)

$ErrorActionPreference = "Stop"

# Docker's own restart:unless-stopped policy (set in each service's own
# compose.yaml) resumes these containers whenever the Docker daemon starts -
# but that daemon only starts if WSL itself is running. This Scheduled Task's
# only job is to wake WSL at logon and bring the target services up, the same
# division of responsibility as WorkstationDashboardAutostart (see
# install-dashboard-autostart.ps1): a restart policy alone does nothing until
# something actually starts the WSL instance.
#
# wsl.exe is a normal System32 binary (unlike pwsh.exe's MSIX Store alias case
# elsewhere in this repo), so a bare name is fine here.

$Distro = "Ubuntu-24.04"
$ServiceArgs = $Services -join " "
$HiddenRunner = Join-Path $PSScriptRoot "run-hidden.vbs"

# Route through wscript.exe + run-hidden.vbs, and use the ScheduledTasks
# module rather than schtasks.exe - confirmed live (2026-09-14) this task, as
# originally written with a plain `schtasks.exe /TR "wsl.exe ..."`, opened a
# visible console window at every logon: Task Scheduler's own task-level
# "Hidden" setting only hides the task from Task Scheduler's UI, it does NOT
# suppress the window a directly-launched wsl.exe allocates (see
# run-hidden.vbs for the full explanation) - matching the exact same gotcha
# already fixed for WorkstationSetupAutoSync/WorkstationAutoUpgrade
# (install-autosync.ps1/install-autoupgrade.ps1), just never applied here
# when this task was first added.
$Action = New-ScheduledTaskAction `
    -Execute "wscript.exe" `
    -Argument "//B `"$HiddenRunner`" `"wsl.exe`" -d $Distro -- bash -lc `"workstation services up $ServiceArgs`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "WorkstationDevServicesAutostart" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Force |
    Out-Null

Write-Host "Dev-services autostart-at-logon task installed for: $ServiceArgs"
Write-Host "This only wakes WSL/starts the containers - the actual restart:unless-stopped"
Write-Host "policy already lives in each service's own compose.yaml."
