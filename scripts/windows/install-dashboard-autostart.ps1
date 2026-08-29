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
$TaskCommand = "wsl.exe -d $Distro -- bash -lc `"systemctl --user start workstation-dashboard.service`""

schtasks.exe /Create /F /SC ONLOGON /TN "WorkstationDashboardAutostart" /TR $TaskCommand /RL LIMITED
if ($LASTEXITCODE -ne 0) { throw "Could not create dashboard autostart scheduled task." }

Write-Host "Dashboard autostart-at-logon task installed."
Write-Host "This only wakes WSL/starts the service - install the systemd unit first with:"
Write-Host "  wsl.exe -d $Distro -- bash -lc 'workstation dashboard enable'"
