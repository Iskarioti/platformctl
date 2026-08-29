param(
    [Parameter(Position=0)]
    [ValidateSet("enable","disable","once","status")]
    [string]$Action = "status",

    [Parameter(Position=1)]
    [int]$Port = 8765
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Distro = "Ubuntu-24.04"

if ($IsWindows -or $env:OS -eq "Windows_NT") {
    switch ($Action) {
        "enable" {
            # Two parts: the WSL-side systemd service (always-on, restarts on
            # failure) and the Windows-side logon trigger (wakes WSL, which a
            # systemd unit alone can't do). See install-dashboard-autostart.ps1
            # for why this invokes through pwsh.exe -File.
            & wsl.exe -d $Distro -- bash -lc "workstation dashboard enable $Port"
            & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\install-dashboard-autostart.ps1")
        }
        "disable" {
            & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\uninstall-dashboard-autostart.ps1")
            & wsl.exe -d $Distro -- bash -lc "workstation dashboard disable"
        }
        "once" { & platformctl.exe serve --port $Port }
        "status" {
            & wsl.exe -d $Distro -- bash -lc "systemctl --user status workstation-dashboard.service --no-pager -l"
            schtasks.exe /Query /TN "WorkstationDashboardAutostart" 2>$null
        }
    }
} else {
    if ($Action -eq "once") {
        & platformctl serve --port $Port
    } elseif ($Action -eq "enable") {
        & bash (Join-Path $Root "scripts/posix/install-dashboard-service.sh") $Port
    } elseif ($Action -eq "disable") {
        & bash (Join-Path $Root "scripts/posix/uninstall-dashboard-service.sh")
    } else {
        & systemctl --user status workstation-dashboard.service --no-pager -l
    }
}
