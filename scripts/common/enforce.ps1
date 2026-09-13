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

    # Desktop appearance (windows/43-configure-taskbar-appearance.ps1's desired state -
    # see docs/desktop-appearance.md). Checked/repaired here so appearance drift (a
    # Windows feature update resetting a value, a manual change) surfaces the same way
    # as any other policy drift, instead of only ever being applied once at bootstrap.
    # --repair runs the appearance script FIRST, then checks reflect the repaired
    # state (matching scripts/posix/enforce.sh's repair-then-report convention),
    # rather than reporting stale failures for a value that was just fixed.
    if ($Repair) {
        Write-Host ""
        Write-Host "Repairing desktop appearance..." -ForegroundColor Cyan
        pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "windows\43-configure-taskbar-appearance.ps1") -NoRestartExplorer
        if ($LASTEXITCODE -ne 0) {
            Warn "Desktop appearance repair script exited non-zero ($LASTEXITCODE)"
        }
    }

    function Get-RegValue([string]$Path, [string]$Name) {
        (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
    }

    $AdvancedKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $PersonalizeKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
    $SearchKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search"
    $StartPolicyKey = "HKCU:\Software\Policies\Microsoft\Windows\Explorer"
    $StartKey = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Start"

    $DesiredAppearance = @(
        @{ Path = $AdvancedKey; Name = "TaskbarAl"; Value = 1; Label = "Taskbar centered" }
        @{ Path = $SearchKey; Name = "SearchboxTaskbarMode"; Value = 0; Label = "Search hidden" }
        @{ Path = $AdvancedKey; Name = "DontUsePowerShellOnWinX"; Value = 0; Label = "Win+X shows Windows PowerShell" }
        @{ Path = $AdvancedKey; Name = "ShowTaskViewButton"; Value = 0; Label = "Task View button hidden" }
        @{ Path = $PersonalizeKey; Name = "AppsUseLightTheme"; Value = 0; Label = "Apps dark mode" }
        @{ Path = $PersonalizeKey; Name = "SystemUsesLightTheme"; Value = 0; Label = "System dark mode" }
        @{ Path = $StartPolicyKey; Name = "HideRecommendedSection"; Value = 1; Label = "Start Recommended section hidden" }
        @{ Path = $StartPolicyKey; Name = "HideCategoryView"; Value = 0; Label = "Start Category view available" }
        @{ Path = $StartKey; Name = "AllAppsViewMode"; Value = 0; Label = "Start All Apps in Category view" }
    )

    $AppearanceDrift = $false
    foreach ($Item in $DesiredAppearance) {
        $Current = Get-RegValue $Item.Path $Item.Name
        if ($Current -eq $Item.Value) {
            Pass "Desktop appearance: $($Item.Label)"
        } else {
            $AppearanceDrift = $true
            Fail "Desktop appearance: $($Item.Label) (current: $Current, expected: $($Item.Value))"
        }
    }

    # TaskbarDa (Widgets) is checked separately: Windows's own UCPD (User Choice
    # Protection Driver) blocks direct registry writes to this value on any
    # sufficiently-updated Windows 11 install (confirmed - see
    # docs/desktop-appearance.md), so a mismatch here is a WARN, never a FAIL, and
    # does not by itself trigger --repair. See that doc for the two supported
    # manual alternatives (Settings toggle, or uninstalling the Widgets app).
    $WidgetsValue = Get-RegValue $AdvancedKey "TaskbarDa"
    if ($WidgetsValue -eq 0) {
        Pass "Desktop appearance: Widgets hidden"
    } else {
        Warn "Desktop appearance: Widgets not hidden (current: $WidgetsValue) - blocked by UCPD, not fixable via registry; see docs/desktop-appearance.md for manual alternatives"
    }

    if (Get-Process -Name "BingWallpaper" -ErrorAction SilentlyContinue) {
        Pass "Desktop appearance: Bing Wallpaper running"
    } else {
        $AppearanceDrift = $true
        Fail "Desktop appearance: Bing Wallpaper not running"
    }

    if ($AppearanceDrift -and -not $Repair) {
        Write-Host "  (run 'workstation enforce --repair' to fix desktop appearance drift)" -ForegroundColor Yellow
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
