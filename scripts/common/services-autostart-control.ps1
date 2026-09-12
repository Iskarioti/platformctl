param(
    [Parameter(Position=0)]
    [ValidateSet("enable","disable","status")]
    [string]$Action = "status",

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Services
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Distro = "Ubuntu-24.04"

if (-not $Services -or $Services.Count -eq 0) { $Services = @("redis", "redisinsight") }
$ServiceArgs = $Services -join " "

if ($IsWindows -or $env:OS -eq "Windows_NT") {
    switch ($Action) {
        "enable" {
            # Two parts: the WSL-side "docker.service enabled + containers up"
            # (Docker's own restart:unless-stopped then keeps them running) and
            # the Windows-side logon trigger (wakes WSL, which a restart policy
            # alone can't do). See install-dev-services-autostart.ps1 for why
            # this invokes through pwsh.exe -File.
            & wsl.exe -d $Distro -- bash -lc "workstation services autostart enable $ServiceArgs"
            & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\install-dev-services-autostart.ps1") @Services
        }
        "disable" {
            & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\uninstall-dev-services-autostart.ps1")
            & wsl.exe -d $Distro -- bash -lc "workstation services autostart disable $ServiceArgs"
        }
        "status" {
            & wsl.exe -d $Distro -- bash -lc "workstation services autostart status $ServiceArgs"
            schtasks.exe /Query /TN "WorkstationDevServicesAutostart" 2>$null
        }
    }
} else {
    & bash (Join-Path $Root "scripts/posix/services.sh") autostart $Action @Services
}
