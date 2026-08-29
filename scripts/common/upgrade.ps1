[CmdletBinding()]
param(
    [string[]]$Scope,
    [switch]$Unattended
)

$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Config = Get-Content (Join-Path $Root "workstation.json") -Raw | ConvertFrom-Json

$StateDir = Join-Path $Root ".state"
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
$LogPath = Join-Path $StateDir ("upgrade-{0}.log" -f (Get-Date -Format "yyyy-MM-dd"))

function Write-Log {
    param([string]$Message)
    $Line = "[{0}] {1}" -f (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK"), $Message
    Write-Host $Line
    Add-Content -LiteralPath $LogPath -Value $Line
}

if (-not $Config.autoUpdate -or -not $Config.autoUpdate.enabled) {
    Write-Log "SKIP: autoUpdate.enabled is false (or unset) in workstation.json."
    exit 0
}

$RequestedScope = if ($Scope -and $Scope.Count -gt 0) { $Scope } else { $Config.autoUpdate.scope }
if (-not $RequestedScope -or $RequestedScope -contains "all") {
    $RequestedScope = @("packages", "vscodeExtensions", "fonts")
}

if ($Unattended) {
    $WindowStart = $Config.autoUpdate.schedule.windowStart
    $WindowEnd = $Config.autoUpdate.schedule.windowEnd

    if ($WindowStart -and $WindowEnd) {
        $Fmt = "HH:mm"
        $Culture = [System.Globalization.CultureInfo]::InvariantCulture
        $Start = [datetime]::ParseExact($WindowStart, $Fmt, $Culture)
        $End = [datetime]::ParseExact($WindowEnd, $Fmt, $Culture)
        $Now = [datetime]::ParseExact((Get-Date -Format $Fmt), $Fmt, $Culture)

        $InWindow = if ($Start -le $End) {
            $Now -ge $Start -and $Now -lt $End
        } else {
            # Window wraps past midnight, e.g. 22:00-06:00.
            $Now -ge $Start -or $Now -lt $End
        }

        if (-not $InWindow) {
            Write-Log "SKIP: outside configured update window ($WindowStart-$WindowEnd)."
            exit 0
        }
    }

    if ($Config.autoUpdate.skipIfContainersRunning) {
        $Containers = & docker ps --format "{{.Names}}" 2>$null
        if ($LASTEXITCODE -eq 0 -and $Containers) {
            Write-Log "SKIP: containers currently running ($($Containers -join ', ')); not disturbing active work."
            exit 0
        }
    }
}

Write-Log "Starting workstation upgrade. Scope: $($RequestedScope -join ', ')"
$Failures = 0

function Invoke-ScopeScript {
    param(
        [string]$Label,
        [string]$RelativePath
    )
    $Path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log "SKIP $Label`: script not found: $RelativePath"
        return
    }
    Write-Log "RUN $Label ($RelativePath)"
    & pwsh.exe -NoLogo -NoProfile -File $Path 2>&1 | ForEach-Object { Write-Log "  $_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Log "FAIL $Label (exit $LASTEXITCODE)"
        $script:Failures++
    } else {
        Write-Log "DONE $Label"
    }
}

foreach ($Item in $RequestedScope) {
    switch ($Item) {
        "packages" {
            $IsAdmin = ([Security.Principal.WindowsPrincipal] `
                [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

            if (-not $IsAdmin) {
                Write-Log "SKIP packages: winget package upgrade requires an elevated session (windows/10-install-tools.ps1 requires admin)."
                continue
            }
            Invoke-ScopeScript -Label "packages" -RelativePath "windows\10-install-tools.ps1"
        }
        "vscodeExtensions" {
            Invoke-ScopeScript -Label "vscodeExtensions" -RelativePath "scripts\windows\configure-vscode.ps1"
        }
        "fonts" {
            Invoke-ScopeScript -Label "fonts" -RelativePath "windows\41-install-fonts.ps1"
        }
        default {
            Write-Log "SKIP unknown scope item: $Item"
        }
    }
}

Write-Log "workstation upgrade completed. Failures: $Failures"
if ($Failures -gt 0) { exit 1 }
exit 0
