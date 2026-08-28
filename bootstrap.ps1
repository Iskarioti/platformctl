# Compatible bootstrap entrypoint for a newly cloned Windows repository.
param(
    [switch]$NoAutoSync,
    [switch]$NoWSL
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

if (-not (Get-Command pwsh.exe -ErrorAction SilentlyContinue)) {
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "PowerShell 7 and winget are unavailable. Install PowerShell 7, then rerun bootstrap.ps1."
    }

    Write-Host "Installing PowerShell 7..."
    winget.exe install --id Microsoft.PowerShell --exact --source winget `
        --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        throw "PowerShell 7 installation failed."
    }
}

$args2 = @("bootstrap")
if ($NoAutoSync) { $args2 += "--no-autosync" }
if ($NoWSL) { $args2 += "--no-wsl" }

& pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") @args2
exit $LASTEXITCODE
