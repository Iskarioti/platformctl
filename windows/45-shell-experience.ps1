#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$SkipPackageInstall,
    [switch]$KeepStarship
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

function Install-WingetPackage {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    Write-Host "Checking $Name [$Id]..."
    winget list --id $Id --exact --source winget 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  already installed"
        return
    }

    winget install --id $Id --exact --source winget --silent `
        --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install $Name [$Id]"
    }
}

function Remove-WingetPackageIfPresent {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )

    winget list --id $Id --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        return
    }

    Write-Host "Removing legacy $Name [$Id]..."
    winget uninstall --id $Id --exact --source winget --silent `
        --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Could not uninstall $Name automatically. It is no longer used by the workstation profile."
    }
}

if (-not $SkipPackageInstall) {
    Install-WingetPackage -Id "JanDeDobbeleer.OhMyPosh" -Name "Oh My Posh"
    Install-WingetPackage -Id "ajeetdsouza.zoxide" -Name "zoxide"
    Install-WingetPackage -Id "junegunn.fzf" -Name "fzf"

    if (-not $KeepStarship) {
        Remove-WingetPackageIfPresent -Id "Starship.Starship" -Name "Starship"
    }
}

$ConfigDir = Join-Path $HOME ".config"
$PoshConfigDir = Join-Path $ConfigDir "oh-my-posh"
New-Item -ItemType Directory -Force -Path $PoshConfigDir | Out-Null

$LegacyStarship = Join-Path $ConfigDir "starship.toml"
if ((-not $KeepStarship) -and (Test-Path $LegacyStarship)) {
    $LegacyBackup = "$LegacyStarship.migrated.$(Get-Date -Format yyyyMMdd-HHmmss).bak"
    Move-Item $LegacyStarship $LegacyBackup
    Write-Host "Backed up legacy Starship config: $LegacyBackup"
}

# Write clean local files rather than carrying alternate data streams from a
# downloaded archive into the user's configuration.
$ThemeSource = Join-Path $Root "shell\oh-my-posh\tokyonight-architect.omp.json"
$ThemeTarget = Join-Path $PoshConfigDir "tokyonight-architect.omp.json"
Get-Content $ThemeSource -Raw | Set-Content -Path $ThemeTarget -Encoding utf8

$ProfileDir = Split-Path -Parent $PROFILE
New-Item -ItemType Directory -Force -Path $ProfileDir | Out-Null

if (Test-Path $PROFILE) {
    $Backup = "$PROFILE.backup.$(Get-Date -Format yyyyMMdd-HHmmss)"
    Copy-Item $PROFILE $Backup
    Write-Host "Backed up existing profile: $Backup"
}

$ProfileSource = Join-Path $Root "shell\powershell\Microsoft.PowerShell_profile.ps1"
Get-Content $ProfileSource -Raw | Set-Content -Path $PROFILE -Encoding utf8

Write-Host ""
Write-Host "Advanced PowerShell + Oh My Posh shell installed." -ForegroundColor Green
Write-Host "Theme:   $ThemeTarget"
Write-Host "Profile: $PROFILE"
Write-Host "Language mode: $($ExecutionContext.SessionState.LanguageMode)"

if ($ExecutionContext.SessionState.LanguageMode -eq "ConstrainedLanguage") {
    Write-Host "CLM detected: the profile keeps App Control intact and uses CLM-safe integrations."
}

Write-Host ""
Write-Host "Do not reload this managed profile with '. `$PROFILE' on CLM endpoints."
Write-Host "Close the PowerShell process and open a fresh PowerShell 7 tab instead."
