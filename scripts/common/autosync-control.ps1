param(
    [Parameter(Position=0)]
    [ValidateSet("enable","disable","once","status","pause","resume")]
    [string]$Action = "status",

    [Parameter(Position=1)]
    [int]$Minutes = 30
)

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ($Action -eq "pause") {
    $StateDir = Join-Path $Root ".state"
    New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
    $Expiry = (Get-Date).ToUniversalTime().AddMinutes($Minutes).ToString("yyyy-MM-ddTHH:mm:ssZ")
    Set-Content -Path (Join-Path $StateDir "autosync.pause") -Value $Expiry -NoNewline
    Write-Host "Autosync paused until $Expiry (run 'workstation autosync resume' to lift early)."
    exit 0
}

if ($Action -eq "resume") {
    Remove-Item (Join-Path $Root ".state\autosync.pause") -Force -ErrorAction SilentlyContinue
    Write-Host "Autosync resumed."
    exit 0
}

if ($IsWindows -or $env:OS -eq "Windows_NT") {
    # Invoke through pwsh.exe -File rather than "& (Join-Path ...)" directly:
    # on managed endpoints running ConstrainedLanguage/App Control, invoking a
    # dynamically-computed path as the command itself is untrusted and fails
    # with "term ... is not recognized", even though the file exists and the
    # same script runs fine as a top-level -File launch (as bootstrap.ps1 does).
    switch ($Action) {
        "enable"  { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\install-autosync.ps1") }
        "disable" { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\windows\uninstall-autosync.ps1") }
        "once"    { & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\common\autosync.ps1") -Once }
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
