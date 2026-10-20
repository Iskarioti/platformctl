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
        # Real bug found live, 2026-10-20: `dev-redis`/`dev-redisinsight` are
        # the DEFAULT `workstation services autostart` services (see
        # scripts/common/services-autostart-control.ps1) - by this repo's own
        # design they run continuously, 24/7, surviving reboots. Once that
        # feature actually works (it does, confirmed this session), this
        # check's blanket "any container running at all = someone's doing
        # active work, don't disturb it" was ALWAYS true from then on,
        # because those two containers are never NOT running - silently
        # neutering autoupgrade entirely. Confirmed from a month of real
        # .state/upgrade-*.log history: every single run since roughly
        # late September skipped, nearly all citing exactly these two
        # container names as the reason. Excluding the specific baseline
        # autostart containers restores the check's actual intent (skip for
        # genuinely active, ad-hoc work - a lab, a dev container someone is
        # using right now - not for a service this repo itself keeps
        # permanently running).
        $BaselineAutostartContainers = @("dev-redis", "dev-redisinsight")
        $Containers = & docker ps --format "{{.Names}}" 2>$null
        $ActiveContainers = @($Containers | Where-Object { $BaselineAutostartContainers -notcontains $_ })
        if ($LASTEXITCODE -eq 0 -and $ActiveContainers.Count -gt 0) {
            Write-Log "SKIP: containers currently running ($($ActiveContainers -join ', ')); not disturbing active work."
            exit 0
        }
    }
}

Write-Log "Starting workstation upgrade. Scope: $($RequestedScope -join ', ')"
$Failures = 0

function Invoke-ScopeScript {
    param(
        [string]$Label,
        [string]$RelativePath,
        [string[]]$Arguments = @()
    )
    $Path = Join-Path $Root $RelativePath
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        Write-Log "SKIP $Label`: script not found: $RelativePath"
        return
    }
    Write-Log "RUN $Label ($RelativePath)"
    & pwsh.exe -NoLogo -NoProfile -File $Path @Arguments 2>&1 | ForEach-Object { Write-Log "  $_" }
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
            # windows\11-install-native-ai-tools.ps1 (Claude Code, Codex CLI,
            # Claude desktop) deliberately needs no elevation - unlike
            # winget's package list below, run it unconditionally rather
            # than gating it behind the same admin check that's only there
            # because 10-install-tools.ps1 itself requires admin. A
            # non-elevated `workstation upgrade` run should still be able to
            # keep these current/self-healing.
            Invoke-ScopeScript -Label "packages (native AI tools)" -RelativePath "windows\11-install-native-ai-tools.ps1"

            $IsAdmin = ([Security.Principal.WindowsPrincipal] `
                [Security.Principal.WindowsIdentity]::GetCurrent()
            ).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)

            if (-not $IsAdmin) {
                Write-Log "SKIP packages: winget package upgrade requires an elevated session (windows/10-install-tools.ps1 requires admin)."
                continue
            }
            # windows\10-install-tools.ps1 itself now reinstates managed app
            # configuration/state (e.g. relaunching Bing Wallpaper if a
            # reinstall stopped it) at its own tail, unconditionally - moved
            # there (2026-09-14) so it's self-contained for ANY caller, not
            # just this one. No separate step needed here any more.
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
