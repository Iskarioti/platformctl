$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
& (Join-Path $Root "scripts\ci\validate.ps1")

$Platform = if ($env:OS -eq "Windows_NT") {
    "Windows"
} elseif ($IsMacOS) {
    "macOS"
} elseif ($IsLinux) {
    "Linux"
} else {
    $PSVersionTable.OS
}

Write-Host "DRY RUN"
Write-Host "OS:   $Platform"
Write-Host "Repo: $Root"
Write-Host "Would install platform packages, fonts, shell configuration, editor config,"
Write-Host "git hooks, global workstation command and autosync service."
