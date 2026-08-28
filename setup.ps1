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
    param([string]$Path, [string[]]$Args)
    $Full = Join-Path $Root $Path
    & $Full @Args
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

switch ($Command.ToLowerInvariant()) {
    "bootstrap" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript "platform\windows\bootstrap.ps1" $Rest
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
            Invoke-RepoScript "scripts\windows\apply.ps1" $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/apply.sh") @Rest
        }
    }

    "validate" {
        Invoke-RepoScript "scripts\ci\validate.ps1" $Rest
    }

    "doctor" {
        Invoke-RepoScript "scripts\common\doctor.ps1" $Rest
    }

    "sync" {
        Invoke-RepoScript "scripts\common\autosync.ps1" @("--once") + $Rest
    }

    "publish" {
        Invoke-RepoScript "scripts\github\publish.ps1" $Rest
    }

    "autosync" {
        Invoke-RepoScript "scripts\common\autosync-control.ps1" $Rest
    }

    "update" {
        git pull --rebase --autostash
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") validate
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") apply
        & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") doctor
    }

    "dry-run" {
        Invoke-RepoScript "scripts\ci\dry-run.ps1" $Rest
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
