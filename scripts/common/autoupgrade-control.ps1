param(
    [Parameter(Position=0)]
    [ValidateSet("enable","disable","once","status")]
    [string]$Action = "status"
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ($IsWindows -or $env:OS -eq "Windows_NT") {
    # See autosync-control.ps1 for why this invokes through pwsh.exe -File
    # rather than "& (Join-Path ...)" directly.
    switch ($Action) {
        "enable"  { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\install-autoupgrade.ps1") }
        "disable" { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\uninstall-autoupgrade.ps1") }
        "once"    { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\common\upgrade.ps1") }
        "status"  { Get-ScheduledTaskInfo -TaskName "WorkstationAutoUpgrade" -ErrorAction SilentlyContinue |
                        Format-List TaskName, LastRunTime, LastTaskResult, NextRunTime }
    }
} else {
    if ($Action -eq "once") {
        & bash (Join-Path $Root "scripts/posix/upgrade.sh")
    } elseif ($Action -eq "enable") {
        & bash (Join-Path $Root "scripts/posix/install-autoupgrade.sh")
    } elseif ($Action -eq "disable") {
        & bash (Join-Path $Root "scripts/posix/uninstall-autoupgrade.sh")
    } else {
        Write-Host "Use platform-native service status commands documented in docs/auto-update.md."
    }
}
