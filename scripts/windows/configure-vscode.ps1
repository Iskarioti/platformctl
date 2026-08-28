#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$TargetDir = Join-Path $env:APPDATA "Code\User"
New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null

$Target = Join-Path $TargetDir "settings.json"
if (Test-Path $Target) {
    Copy-Item $Target "$Target.backup.$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
}

Copy-Item (Join-Path $Root "vscode\settings.json") $Target -Force

if (Get-Command code.cmd -ErrorAction SilentlyContinue) {
    foreach ($Extension in Get-Content (Join-Path $Root "vscode\extensions.txt")) {
        $Extension = $Extension.Trim()
        if ($Extension) {
            code.cmd --install-extension $Extension --force | Out-Null
        }
    }
}

Write-Host "VS Code configured with official JetBrains Mono editor font and JetBrainsMono Nerd Font terminal font."
