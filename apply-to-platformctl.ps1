#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoPath
)

$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Overlay = Join-Path $PackageRoot 'overlay'
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoPath 'setup.ps1'))) {
    throw "Not a platformctl repository: $RepoPath"
}

$BackupRoot = Join-Path $RepoPath ('.state\shell-fix-backup-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

Get-ChildItem -LiteralPath $Overlay -Recurse -Force -File | ForEach-Object {
    $Relative = [IO.Path]::GetRelativePath($Overlay, $_.FullName)
    $Destination = Join-Path $RepoPath $Relative
    $DestinationDir = Split-Path -Parent $Destination
    New-Item -ItemType Directory -Force -Path $DestinationDir | Out-Null

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        $Backup = Join-Path $BackupRoot $Relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Backup) | Out-Null
        Copy-Item -LiteralPath $Destination -Destination $Backup -Force
    }

    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Force
    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
    Write-Host "COPIED $Relative"
}

Get-ChildItem -LiteralPath $RepoPath -Recurse -Force -File -ErrorAction SilentlyContinue |
    ForEach-Object { Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue }

Write-Host ""
Write-Host "Shell configuration overlay applied." -ForegroundColor Green
Write-Host "Backup: $BackupRoot"
Write-Host ""
Write-Host "Next:"
Write-Host "  pwsh.exe -NoLogo -NoProfile -File .\setup.ps1 validate"
Write-Host "  wsl.exe -d Ubuntu-24.04 -- bash -lc 'cd /mnt/c/.../platformctl && ./setup apply'"
