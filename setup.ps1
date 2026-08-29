[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Invoke-RepoScript {
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [string[]]$Arguments = @()
    )

    $Full = Join-Path $Root $Path

    if (-not (Test-Path -LiteralPath $Full -PathType Leaf)) {
        throw "Required setup component not found: $Full"
    }

    Write-Host "Running: $Path"

    pwsh.exe `
        -NoLogo `
        -NoProfile `
        -File $Full `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$Path failed with exit code $LASTEXITCODE"
    }
}

switch ($Command.ToLowerInvariant()) {
    "bootstrap" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "platform\windows\bootstrap.ps1" -Arguments $Rest
        } elseif ($IsMacOS) {
            & bash (Join-Path $Root "platform/macos/bootstrap.sh") @Rest
        } elseif ($IsLinux) {
            & bash (Join-Path $Root "platform/linux/bootstrap.sh") @Rest
        } else {
            throw "Unsupported platform."
        }
    }

    "apply" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript  -Path "scripts\windows\apply.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/apply.sh") @Rest
        }
    }

    "validate" {
        Invoke-RepoScript -Path "scripts\ci\validate.ps1" -Arguments $Rest
    }

    "doctor" {
        Invoke-RepoScript -Path "scripts\common\doctor.ps1" -Arguments $Rest
    }

    "sync" {
        Invoke-RepoScript -Path "scripts\common\autosync.ps1" -Arguments @("--once") + $Rest
    }

    "publish" {
        Invoke-RepoScript -Path "scripts\github\publish.ps1" -Arguments $Rest
    }

    "autosync" {
        Invoke-RepoScript -Path "scripts\common\autosync-control.ps1" -Arguments $Rest
    }

    "update" {
        git pull --rebase --autostash
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") validate
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") apply
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") doctor
    }

    "dry-run" {
        Invoke-RepoScript -Path "scripts\ci\dry-run.ps1" -Arguments $Rest
    }

    default {
        @"
workstation setup commands

  bootstrap             install/adapt everything for this platform
  apply                 copy canonical configs to live destinations
  validate              validate source and safety invariants
  doctor                inspect installed workstation health
  sync                  validate -> apply -> commit -> push once
  autosync enable       install background autosync
  autosync disable      remove background autosync
  publish [owner/repo]  create/publish the GitHub repository using gh
  update                pull/rebase latest source, validate, apply and doctor
  dry-run               CI-safe platform simulation
"@ | Write-Host
    }
}
