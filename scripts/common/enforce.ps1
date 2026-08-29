[CmdletBinding()]
param([switch]$Repair)

$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$PolicyPath = Join-Path $Root "policy\development.json"

if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
    Write-Error "Development policy not found: $PolicyPath"
    exit 2
}

$Policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$Failures = 0
$Warnings = 0

function Pass([string]$Message) { Write-Host "PASS  $Message" -ForegroundColor Green }
function Warn([string]$Message) { $script:Warnings++; Write-Warning $Message }
function Fail([string]$Message) { $script:Failures++; Write-Host "FAIL  $Message" -ForegroundColor Red }

Write-Host "=== Development Environment Enforcement ===" -ForegroundColor Cyan
Write-Host "Policy: $PolicyPath"
Write-Host ""

if ($env:OS -eq "Windows_NT") {
    Pass "Host platform: Windows"

    $WorkstationShim = Join-Path $HOME ".local\bin\workstation.cmd"
    if (Test-Path -LiteralPath $WorkstationShim -PathType Leaf) {
        Pass "Native workstation command shim"
    } else {
        Fail "Native workstation command shim missing: $WorkstationShim"
    }

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        Fail "WSL is required but wsl.exe is unavailable"
    } else {
        Pass "WSL executable available"

        $TargetDistro = $Policy.windows.wslDistribution
        $Raw = wsl.exe --list --quiet 2>$null
        $Distros = @()
        foreach ($Line in $Raw) {
            $Name = ($Line -replace "`0", "").Trim()
            if ($Name) { $Distros += $Name }
        }

        if ($Distros -contains $TargetDistro) {
            Pass "$TargetDistro installed"

            $VersionOutput = ((wsl.exe --list --verbose 2>$null) -join "`n") -replace "`0", ""
            if ($VersionOutput -match ([regex]::Escape($TargetDistro) + "\s+\S+\s+2")) {
                Pass "$TargetDistro uses WSL2"
            } else {
                Fail "$TargetDistro is not reporting WSL2"
            }

            $RepoLinux = (
                wsl.exe -d $TargetDistro -- wslpath -a -u $Root.Path 2>$null |
                Select-Object -First 1
            )

            if ($RepoLinux) {
                $WslArgs = @("$RepoLinux/scripts/posix/enforce.sh")
                if ($Repair) { $WslArgs += "--repair" }

                wsl.exe -d $TargetDistro -- bash @WslArgs
                if ($LASTEXITCODE -eq 0) {
                    Pass "WSL development plane complies with policy"
                } else {
                    Fail "WSL development plane has policy violations"
                }
            } else {
                Fail "Could not translate the platformctl repository path into WSL"
            }
        } else {
            Fail "$TargetDistro is required by development policy"
        }
    }

    if (-not $Policy.windows.dockerDesktopAllowed) {
        $DockerDesktopRunning = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
        if ($DockerDesktopRunning) {
            Fail "Docker Desktop is running; policy requires Docker Engine inside WSL"
        } else {
            Pass "Docker Desktop is not running"
        }
    }
} else {
    $Args = @()
    if ($Repair) { $Args += "--repair" }
    & bash (Join-Path $Root "scripts/posix/enforce.sh") @Args
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Failures: $Failures"
Write-Host "Warnings: $Warnings"

if ($Failures -gt 0) {
    Write-Host "RESULT: NON-COMPLIANT" -ForegroundColor Red
    exit 1
}

Write-Host "RESULT: COMPLIANT" -ForegroundColor Green
exit 0
