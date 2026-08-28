param(
    [Parameter(Position=0)]
    [ValidateSet("enable","disable","once","status")]
    [string]$Action = "status"
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ($IsWindows -or $env:OS -eq "Windows_NT") {
    switch ($Action) {
        "enable"  { & (Join-Path $Root "scripts\windows\install-autosync.ps1") }
        "disable" { & (Join-Path $Root "scripts\windows\uninstall-autosync.ps1") }
        "once"    { & (Join-Path $Root "scripts\common\autosync.ps1") -Once }
        "status"  { schtasks.exe /Query /TN "WorkstationSetupAutoSync" }
    }
} else {
    if ($Action -eq "once") {
        & bash (Join-Path $Root "scripts/common/autosync.sh") --once
    } elseif ($Action -eq "enable") {
        & bash (Join-Path $Root "scripts/posix/install-autosync.sh")
    } elseif ($Action -eq "disable") {
        & bash (Join-Path $Root "scripts/posix/uninstall-autosync.sh")
    } else {
        Write-Host "Use platform-native service status commands documented in docs/autosync.md."
    }
}
