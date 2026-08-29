#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"

$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Overlay = Join-Path $PackageRoot "overlay"

$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoPath "setup.ps1"))) {
    throw "Not a platformctl repository: $RepoPath"
}

$BackupRoot = Join-Path $RepoPath (".state\editor-upgrade-backup-" + (Get-Date -Format "yyyyMMdd-HHmmss"))
New-Item -ItemType Directory -Force -Path $BackupRoot | Out-Null

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return
    }

    $Relative = [IO.Path]::GetRelativePath($RepoPath, $Path)
    $Target = Join-Path $BackupRoot $Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $Target -Force
}

Write-Host "=== Copying editor management files ===" -ForegroundColor Cyan

Get-ChildItem -LiteralPath $Overlay -Recurse -Force -File | ForEach-Object {
    $Relative = [IO.Path]::GetRelativePath($Overlay, $_.FullName)
    $Destination = Join-Path $RepoPath $Relative

    if (Test-Path -LiteralPath $Destination -PathType Leaf) {
        Backup-File -Path $Destination
    }

    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null

    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Force
    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue

    Write-Host "COPIED $Relative"
}

# ------------------------------------------------------------------
# Patch setup.ps1 without replacing any local enforcement/services work.
# ------------------------------------------------------------------
$SetupPs1 = Join-Path $RepoPath "setup.ps1"
$SetupText = Get-Content -LiteralPath $SetupPs1 -Raw

if ($SetupText -notmatch '(?m)^\s*"editor"\s*\{') {
    Backup-File -Path $SetupPs1

    $EditorCase = @'
    "editor" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            wsl.exe -d Ubuntu-24.04 -- bash -lc 'workstation editor "$@"' -- @Rest
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        } else {
            & bash (Join-Path $Root "scripts/posix/editor.sh") @Rest
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }

'@

    $Anchor = '    "update" {'
    if (-not $SetupText.Contains($Anchor)) {
        $Anchor = '    "dry-run" {'
    }

    if (-not $SetupText.Contains($Anchor)) {
        throw "Could not locate a safe insertion point in setup.ps1"
    }

    $SetupText = $SetupText.Replace($Anchor, $EditorCase + $Anchor)

    if ($SetupText -notmatch '(?m)^\s+editor\s+') {
        $SetupText = $SetupText.Replace(
            '  doctor                inspect installed workstation health',
            "  doctor                inspect installed workstation health`r`n  editor                install/manage Neovim, NvChad and Vim profiles"
        )
    }

    Set-Content -LiteralPath $SetupPs1 -Value $SetupText -Encoding utf8
    Unblock-File -LiteralPath $SetupPs1 -ErrorAction SilentlyContinue
    Write-Host "PATCHED setup.ps1"
}

# ------------------------------------------------------------------
# Patch POSIX setup dispatcher.
# ------------------------------------------------------------------
$SetupSh = Join-Path $RepoPath "setup"

if (Test-Path -LiteralPath $SetupSh) {
    $Text = Get-Content -LiteralPath $SetupSh -Raw

    if ($Text -notmatch 'validate\|doctor\|editor\|') {
        Backup-File -Path $SetupSh
        $Text = $Text.Replace(
            'validate|doctor|sync|publish|autosync|update|dry-run|help)',
            'validate|doctor|editor|sync|publish|autosync|update|dry-run|help)'
        )
        Set-Content -LiteralPath $SetupSh -Value $Text -Encoding utf8
        Write-Host "PATCHED setup"
    }
}

# ------------------------------------------------------------------
# Patch scripts/posix/workstation.sh.
# ------------------------------------------------------------------
$WorkstationSh = Join-Path $RepoPath "scripts\posix\workstation.sh"

if (Test-Path -LiteralPath $WorkstationSh) {
    $Text = Get-Content -LiteralPath $WorkstationSh -Raw

    if ($Text -notmatch '(?m)^\s*editor\)') {
        Backup-File -Path $WorkstationSh

        $Block = @'
  editor)
    exec "$ROOT/scripts/posix/editor.sh" "$@"
    ;;
'@

        $Anchor = '  sync)'
        if (-not $Text.Contains($Anchor)) {
            $Anchor = '  update)'
        }

        if (-not $Text.Contains($Anchor)) {
            throw "Could not locate a safe insertion point in scripts/posix/workstation.sh"
        }

        $Text = $Text.Replace($Anchor, $Block + $Anchor)
        $Text = $Text.Replace(
            "  doctor`n",
            "  doctor`n  editor install|apply|doctor|list|profile|sync|clean`n"
        )

        Set-Content -LiteralPath $WorkstationSh -Value $Text -Encoding utf8
        Write-Host "PATCHED scripts/posix/workstation.sh"
    }
}

# ------------------------------------------------------------------
# Make editor installation part of Linux/WSL bootstrap.
# ------------------------------------------------------------------
$LinuxBootstrap = Join-Path $RepoPath "platform\linux\bootstrap.sh"

if (Test-Path -LiteralPath $LinuxBootstrap) {
    $Text = Get-Content -LiteralPath $LinuxBootstrap -Raw

    if ($Text -notmatch 'scripts/posix/editor\.sh"\s+install') {
        Backup-File -Path $LinuxBootstrap

        $Anchor = '"$ROOT/platform/linux/install-vscode.sh" || true'
        if (-not $Text.Contains($Anchor)) {
            throw "Could not locate install-vscode.sh in Linux bootstrap"
        }

        $Text = $Text.Replace(
            $Anchor,
            $Anchor + "`n`n" + '"$ROOT/scripts/posix/editor.sh" install'
        )

        Set-Content -LiteralPath $LinuxBootstrap -Value $Text -Encoding utf8
        Write-Host "PATCHED platform/linux/bootstrap.sh"
    }
}

# Remove Mark-of-the-Web from files deliberately installed into the trusted repo.
Get-ChildItem -LiteralPath $RepoPath -Recurse -Force -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }

Write-Host ""
Write-Host "Editor management update applied." -ForegroundColor Green
Write-Host "Backups: $BackupRoot"
Write-Host ""
Write-Host "Validate with:"
Write-Host '  pwsh.exe -NoLogo -NoProfile -File ".\setup.ps1" validate'
Write-Host ""
Write-Host "Then inside WSL:"
Write-Host '  workstation editor install'
Write-Host '  workstation editor doctor'
