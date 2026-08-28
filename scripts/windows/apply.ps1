#Requires -Version 7.0
param([switch]$Quiet)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Copy-ManagedFile {
    param([string]$Source, [string]$Destination)

    $SourcePath = Join-Path $Root $Source
    $DestParent = Split-Path -Parent $Destination
    if ($DestParent) { New-Item -ItemType Directory -Path $DestParent -Force | Out-Null }

    if (Test-Path $Destination) {
        $SourceHash = (Get-FileHash $SourcePath -Algorithm SHA256).Hash
        $DestHash = (Get-FileHash $Destination -Algorithm SHA256).Hash
        if ($SourceHash -eq $DestHash) {
            if (-not $Quiet) { Write-Host "UNCHANGED $Destination" }
            return
        }
        Copy-Item $Destination "$Destination.backup.$(Get-Date -Format yyyyMMdd-HHmmss)" -Force
    }

    Copy-Item $SourcePath $Destination -Force
    if (-not $Quiet) { Write-Host "COPIED    $Destination" }
}

Copy-ManagedFile "shell\oh-my-posh\tokyonight-architect.omp.json" `
    (Join-Path $HOME ".config\oh-my-posh\tokyonight-architect.omp.json")

Copy-ManagedFile "shell\powershell\Microsoft.PowerShell_profile.ps1" $PROFILE

# VS Code
$VsCodeSettings = Join-Path $env:APPDATA "Code\User\settings.json"
Copy-ManagedFile "vscode\settings.json" $VsCodeSettings

# Windows Terminal: locate stable/preview/unpackaged settings folder.
$Candidates = @(
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Packages\Microsoft.WindowsTerminalPreview_8wekyb3d8bbwe\LocalState\settings.json"),
    (Join-Path $env:LOCALAPPDATA "Microsoft\Windows Terminal\settings.json")
)
$TerminalTarget = $Candidates | Where-Object { Test-Path (Split-Path -Parent $_) } | Select-Object -First 1
if ($TerminalTarget) {
    Copy-ManagedFile "windows-terminal\settings.json" $TerminalTarget
}

if (-not $Quiet) {
    Write-Host "Windows configuration applied using Copy-Item only." -ForegroundColor Green
}
