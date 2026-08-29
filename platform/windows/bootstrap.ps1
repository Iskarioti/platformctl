param(
    [switch]$NoAutoSync,
    [switch]$NoWSL
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Run {
    param(
        [Parameter(Mandatory)]
        [string]$Relative,

        [string[]]$Arguments = @()
    )

    $Path = Join-Path $Root $Relative

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required bootstrap component not found: $Path"
    }

    Write-Host ""
    Write-Host "=== $Relative ===" -ForegroundColor Cyan

    pwsh.exe `
        -NoLogo `
        -NoProfile `
        -File $Path `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$Relative failed with exit code $LASTEXITCODE"
    }
}

Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

Run "windows\10-install-tools.ps1"
Run "windows\41-install-fonts.ps1"
Run "windows\42-configure-windows-terminal.ps1"
Run "windows\45-shell-experience.ps1"

if (-not $NoWSL) {
    Run "windows\20-install-wsl.ps1"
    Run "windows\25-set-wsl-profile.ps1"
}

Run "scripts\windows\configure-vscode.ps1"
Run "scripts\common\install-git-hooks.ps1"
Run "scripts\windows\install-workstation-command.ps1"

# Re-apply because the command installer may update the canonical PowerShell profile.
Run "scripts\windows\apply.ps1"

if (-not $NoAutoSync) {
    Run "scripts\windows\install-autosync.ps1"
}

Run "scripts\common\doctor.ps1"

Write-Host "`nWindows workstation bootstrap completed." -ForegroundColor Green
Write-Host "Close Windows Terminal completely and open a new PowerShell 7 session."
