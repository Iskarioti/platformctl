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
    pwsh.exe -NoLogo -NoProfile -File $Full @Arguments
    exit $LASTEXITCODE
}

switch ($Command.ToLowerInvariant()) {
    "bootstrap" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "platform\windows\bootstrap.ps1" -Arguments $Rest
        } elseif ($IsMacOS) {
            & bash (Join-Path $Root "platform/macos/bootstrap.sh") @Rest
            exit $LASTEXITCODE
        } elseif ($IsLinux) {
            & bash (Join-Path $Root "platform/linux/bootstrap.sh") @Rest
            exit $LASTEXITCODE
        } else {
            throw "Unsupported platform."
        }
    }

    "apply" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\windows\apply.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/apply.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "validate" { Invoke-RepoScript -Path "scripts\ci\validate.ps1" -Arguments $Rest }
    "doctor"   { Invoke-RepoScript -Path "scripts\common\doctor.ps1" -Arguments $Rest }
    "enforce"  {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\enforce.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/enforce.sh") @Rest
            exit $LASTEXITCODE
        }
    }
    "project" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\project.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/project.sh") @Rest
            exit $LASTEXITCODE
        }
    }
    "services" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\services.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/services.sh") @Rest
            exit $LASTEXITCODE
        }
    }
    "models" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\models.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/models.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "lab" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\labs.ps1" -Arguments $Rest
        } else {
            & bash (Join-Path $Root "scripts/posix/labs.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "editor" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation "$@"' workstation editor @Rest
            exit $LASTEXITCODE
        } else {
            & bash (Join-Path $Root "scripts/posix/editor.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "sync"     { Invoke-RepoScript -Path "scripts\common\autosync.ps1" -Arguments @("--once") + $Rest }
    "publish"  { Invoke-RepoScript -Path "scripts\github\publish.ps1" -Arguments $Rest }
    "autosync" { Invoke-RepoScript -Path "scripts\common\autosync-control.ps1" -Arguments $Rest }

    "update" {
        git pull --rebase --autostash
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

        foreach ($Action in @("validate","apply","doctor")) {
            & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") $Action
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
        exit 0
    }

    "upgrade"  { Invoke-RepoScript -Path "scripts\common\upgrade.ps1" -Arguments $Rest }
    "autoupgrade" { Invoke-RepoScript -Path "scripts\common\autoupgrade-control.ps1" -Arguments $Rest }

    "dashboard" {
        $SubAction = if ($Rest.Count -gt 0) { $Rest[0] } else { "" }
        if ($SubAction -in @("enable", "disable", "status")) {
            Invoke-RepoScript -Path "scripts\common\dashboard-control.ps1" -Arguments $Rest
        } elseif ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'platformctl serve "$@"' platformctl-serve @Rest
            exit $LASTEXITCODE
        } else {
            & platformctl serve @Rest
            exit $LASTEXITCODE
        }
    }

    "backup" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation backup "$@"' workstation-backup @Rest
            exit $LASTEXITCODE
        } else {
            & bash (Join-Path $Root "scripts/posix/backup.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "changelog" { Invoke-RepoScript -Path "scripts\common\changelog-preview.ps1" -Arguments $Rest }

    "ssh-import" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation ssh-import "$@"' workstation-ssh-import @Rest
            exit $LASTEXITCODE
        } else {
            & bash (Join-Path $Root "wsl/import-windows-ssh-keys.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "restore" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            & wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation restore "$@"' workstation-restore @Rest
            exit $LASTEXITCODE
        } else {
            & bash (Join-Path $Root "scripts/posix/restore.sh") @Rest
            exit $LASTEXITCODE
        }
    }

    "dry-run" { Invoke-RepoScript -Path "scripts\ci\dry-run.ps1" -Arguments $Rest }

    default {
        @"
workstation setup commands

  bootstrap                         install/adapt everything for this platform
  apply                             copy canonical configs to live destinations
  validate                          validate source and safety invariants
  doctor                            inspect installed workstation health
  enforce [--repair]                verify development-policy compliance
  project init <template> <name>    create a governed project
  project check [path]              validate a project against policy
  project doctor [path]             show project/toolchain health
  project open [path]               validate and open project in VS Code
  project templates                 list approved project templates
  services init                     create shared Docker dev network + credentials
  services list                     show predefined Docker development services
  services up [service|profile...]  start services; default profile is core
  services project-up [path]        start services declared by a governed project
  services doctor                   check shared development service health
  services down                     stop catalog containers, preserve data
  models up|down|status             shared local Ollama runtime for testing models
  models pull|list|run <model>      manage/use models in the shared runtime
  lab list|info|up|status|test|...  pre-production architecture validation labs (see docs/labs.md)
  editor install|apply|doctor       manage Neovim/NvChad/Vim editor profiles
  sync                              validate -> apply -> commit -> push once
  autosync enable|disable           manage background platformctl autosync
  autosync pause [minutes]|resume   skip autosync's git-sync step during active multi-step work
  upgrade [--Scope packages,...]    upgrade installed components (winget/VS Code/fonts)
  autoupgrade enable|disable|once   manage off-hours background component upgrades
  dashboard [--port N]              run the platformctl web control plane once (foreground)
  dashboard enable|disable|status   always-on background dashboard service (auto-restart, starts at login)
  backup [output-path]              encrypted backup of control-plane/dev-service secrets and volumes
  restore <backup-file> [--yes]     restore a backup created by "backup"
  changelog [since-commit]          draft a CHANGELOG.md section from Conventional Commits (preview only)
  ssh-import                        copy Windows SSH keys into WSL (WSL only)
  publish [owner/repo]              create/publish the GitHub repository
  update                            pull/rebase, validate, apply, doctor
  dry-run                           CI-safe platform simulation
"@ | Write-Host
    }
}
