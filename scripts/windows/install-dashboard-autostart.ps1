#Requires -Version 7.0
$ErrorActionPreference = "Stop"

# platformctl serve only runs inside WSL. This Scheduled Task's job is purely
# to wake WSL at logon (a "systemctl --user enable"-d unit does nothing until
# something actually starts the WSL instance) and nudge the dashboard service
# to running - the real always-on/restart-on-failure behavior lives in the
# systemd user service installed by scripts/posix/install-dashboard-service.sh.
#
# wsl.exe is a normal System32 binary (unlike pwsh.exe's MSIX Store alias
# case elsewhere in this repo), so a bare name is fine here.

$Distro = "Ubuntu-24.04"
$HiddenRunner = Join-Path $PSScriptRoot "run-hidden.vbs"

# Route through wscript.exe + run-hidden.vbs, and use the ScheduledTasks
# module rather than schtasks.exe - same fix as
# install-dev-services-autostart.ps1, for the same reason: a plain
# `schtasks.exe /TR "wsl.exe ..."` task opens a visible console window at
# every logon regardless of the task's own "Hidden" setting (see
# run-hidden.vbs).
$Action = New-ScheduledTaskAction `
    -Execute "wscript.exe" `
    -Argument "//B `"$HiddenRunner`" `"wsl.exe`" -d $Distro -- bash -lc `"systemctl --user start workstation-dashboard.service`""

$Trigger = New-ScheduledTaskTrigger -AtLogOn
$Settings = New-ScheduledTaskSettingsSet -StartWhenAvailable

Register-ScheduledTask `
    -TaskName "WorkstationDashboardAutostart" `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Force |
    Out-Null

Write-Host "Dashboard autostart-at-logon task installed."
Write-Host "This only wakes WSL/starts the service - install the systemd unit first with:"
Write-Host "  wsl.exe -d $Distro -- bash -lc 'workstation dashboard enable'"
