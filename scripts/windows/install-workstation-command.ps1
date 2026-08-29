#Requires -Version 7.0

<#
.SYNOPSIS
    Installs the global `workstation` command for Windows.

.DESCRIPTION
    Creates a native CMD shim in:

        %USERPROFILE%\.local\bin\workstation.cmd

    and registers that directory in the current user's PATH.

    The implementation deliberately does NOT depend on PowerShell $PROFILE.
    This is required for managed Windows endpoints where:

        - the interactive PowerShell session runs ConstrainedLanguage;
        - App Control / WDAC may execute trusted repository scripts as
          FullLanguage;
        - PowerShell therefore refuses to dot-source the managed profile into
          the ConstrainedLanguage interactive session.

    The workstation command acts as a process boundary:

        workstation
            -> workstation.cmd
            -> pwsh.exe -NoProfile -File <repo>\setup.ps1

    No execution-policy bypass, App Control bypass, WDAC change, or CLM
    weakening is performed.

    This installer is designed to be idempotent.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# ---------------------------------------------------------------------------
# Repository
# ---------------------------------------------------------------------------

$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$SetupScript = Join-Path $Root "setup.ps1"

if (-not (Test-Path -LiteralPath $SetupScript -PathType Leaf)) {
    throw "Required setup script not found: $SetupScript"
}

Write-Host ""
Write-Host "=== Workstation command ===" -ForegroundColor Cyan
Write-Host "Repository: $Root"

# ---------------------------------------------------------------------------
# Managed locations
# ---------------------------------------------------------------------------

$ConfigDir = Join-Path $HOME ".config\workstation"
$RepoPathFile = Join-Path $ConfigDir "repo-path"

$BinDir = Join-Path $HOME ".local\bin"
$CommandPath = Join-Path $BinDir "workstation.cmd"

New-Item `
    -ItemType Directory `
    -Path $ConfigDir `
    -Force |
    Out-Null

New-Item `
    -ItemType Directory `
    -Path $BinDir `
    -Force |
    Out-Null

# ---------------------------------------------------------------------------
# Register repository location
#
# Do not hard-code the repository path into workstation.cmd. Keeping it in a
# small state file means the shim remains stable if the setup repository is
# relocated and this installer is rerun.
# ---------------------------------------------------------------------------

$DesiredRepoPath = $Root.Path

$ExistingRepoPath = $null

if (Test-Path -LiteralPath $RepoPathFile) {
    $ExistingRepoPath = (
        Get-Content `
            -LiteralPath $RepoPathFile `
            -Raw `
            -ErrorAction SilentlyContinue
    ).Trim()
}

if ($ExistingRepoPath -ne $DesiredRepoPath) {

    Set-Content `
        -LiteralPath $RepoPathFile `
        -Value $DesiredRepoPath `
        -Encoding utf8

    Write-Host "REGISTERED repository path:"
    Write-Host "  $DesiredRepoPath"
}
else {
    Write-Host "UNCHANGED  repository path:"
    Write-Host "  $DesiredRepoPath"
}

# ---------------------------------------------------------------------------
# Native command shim
#
# This is intentionally CMD rather than a PowerShell function or .ps1 shim.
# It remains directly executable from ConstrainedLanguage PowerShell and does
# not require importing code into the interactive runspace.
# ---------------------------------------------------------------------------

$CommandContent = @'
@echo off
setlocal EnableExtensions DisableDelayedExpansion

set "WORKSTATION_REPO_FILE=%USERPROFILE%\.config\workstation\repo-path"

if not exist "%WORKSTATION_REPO_FILE%" (
    echo ERROR: Workstation repository path is not registered. 1>&2
    echo Expected: "%WORKSTATION_REPO_FILE%" 1>&2
    exit /b 2
)

set /p WORKSTATION_REPO=<"%WORKSTATION_REPO_FILE%"

if not defined WORKSTATION_REPO (
    echo ERROR: Workstation repository path file is empty. 1>&2
    exit /b 3
)

if not exist "%WORKSTATION_REPO%\setup.ps1" (
    echo ERROR: Workstation setup script was not found. 1>&2
    echo Expected: "%WORKSTATION_REPO%\setup.ps1" 1>&2
    exit /b 4
)

where pwsh.exe >nul 2>&1

if errorlevel 1 (
    echo ERROR: PowerShell 7 ^(pwsh.exe^) is not available in PATH. 1>&2
    exit /b 5
)

pwsh.exe ^
    -NoLogo ^
    -NoProfile ^
    -File "%WORKSTATION_REPO%\setup.ps1" %*

set "WORKSTATION_EXIT_CODE=%ERRORLEVEL%"

endlocal & exit /b %WORKSTATION_EXIT_CODE%
'@

$WriteCommand = $true

if (Test-Path -LiteralPath $CommandPath) {

    $ExistingCommandContent = Get-Content `
        -LiteralPath $CommandPath `
        -Raw `
        -ErrorAction SilentlyContinue

    if ($ExistingCommandContent.TrimEnd() -eq $CommandContent.TrimEnd()) {
        $WriteCommand = $false
    }
}

if ($WriteCommand) {

    Set-Content `
        -LiteralPath $CommandPath `
        -Value $CommandContent `
        -Encoding ascii

    Write-Host "INSTALLED  $CommandPath"
}
else {
    Write-Host "UNCHANGED  $CommandPath"
}

# ---------------------------------------------------------------------------
# Persistent user PATH
#
# Use the registry provider rather than relying on the PowerShell profile.
# This affects future Windows processes for the current user.
#
# No machine-wide PATH is changed.
# ---------------------------------------------------------------------------

$UserEnvironmentKey = "HKCU:\Environment"

$CurrentUserPath = $null

try {

    $CurrentUserPath = Get-ItemPropertyValue `
        -Path $UserEnvironmentKey `
        -Name "Path" `
        -ErrorAction Stop

}
catch {

    # A user-level PATH value does not necessarily exist on a fresh profile.
    $CurrentUserPath = ""
}

$PathAlreadyRegistered = $false

if ($CurrentUserPath) {

    $UserPathEntries = $CurrentUserPath -split ";"

    foreach ($Entry in $UserPathEntries) {

        if (-not $Entry) {
            continue
        }

        $NormalizedEntry = $Entry.Trim().TrimEnd("\")
        $NormalizedBinDir = $BinDir.TrimEnd("\")

        if ($NormalizedEntry -ieq $NormalizedBinDir) {
            $PathAlreadyRegistered = $true
            break
        }
    }
}

if (-not $PathAlreadyRegistered) {

    if ($CurrentUserPath) {
        $NewUserPath = "$($CurrentUserPath.TrimEnd(';'));$BinDir"
    }
    else {
        $NewUserPath = $BinDir
    }

    Set-ItemProperty `
        -Path $UserEnvironmentKey `
        -Name "Path" `
        -Value $NewUserPath

    Write-Host "REGISTERED user PATH:"
    Write-Host "  $BinDir"
}
else {
    Write-Host "UNCHANGED  user PATH:"
    Write-Host "  $BinDir"
}

# ---------------------------------------------------------------------------
# Current bootstrap process PATH
#
# Registry changes apply to future processes. Add the location to this process
# too so the command can be validated immediately.
# ---------------------------------------------------------------------------

$ProcessPathAlreadyRegistered = $false

foreach ($Entry in ($env:PATH -split ";")) {

    if (-not $Entry) {
        continue
    }

    $NormalizedEntry = $Entry.Trim().TrimEnd("\")
    $NormalizedBinDir = $BinDir.TrimEnd("\")

    if ($NormalizedEntry -ieq $NormalizedBinDir) {
        $ProcessPathAlreadyRegistered = $true
        break
    }
}

if (-not $ProcessPathAlreadyRegistered) {
    $env:PATH = "$BinDir;$env:PATH"
}

# ---------------------------------------------------------------------------
# Verify installation
# ---------------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $CommandPath -PathType Leaf)) {
    throw "workstation.cmd was not created successfully: $CommandPath"
}

if (-not (Test-Path -LiteralPath $RepoPathFile -PathType Leaf)) {
    throw "Repository registration file was not created: $RepoPathFile"
}

$RegisteredRepo = (
    Get-Content `
        -LiteralPath $RepoPathFile `
        -Raw
).Trim()

if ($RegisteredRepo -ne $DesiredRepoPath) {
    throw "Repository path verification failed."
}

$ResolvedCommand = Get-Command `
    workstation.cmd `
    -ErrorAction SilentlyContinue

if (-not $ResolvedCommand) {
    throw "workstation.cmd exists but could not be resolved through PATH."
}

Write-Host ""
Write-Host "Workstation command installed successfully." -ForegroundColor Green

Write-Host ""
Write-Host "Command:"
Write-Host "  $CommandPath"

Write-Host ""
Write-Host "Repository:"
Write-Host "  $RegisteredRepo"

Write-Host ""
Write-Host "Usage:"
Write-Host "  workstation doctor"
Write-Host "  workstation validate"
Write-Host "  workstation apply"
Write-Host "  workstation update"
Write-Host "  workstation sync"

Write-Host ""
Write-Host "PowerShell profile dependency: NONE"
Write-Host "Interactive CLM compatible:      YES"
Write-Host "Execution-policy bypass:         NO"
Write-Host "App Control / WDAC bypass:       NO"

Write-Host ""
Write-Host "Open a new Windows Terminal process before relying on the persistent PATH."
