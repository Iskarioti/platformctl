$ErrorActionPreference = "Continue"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

$Platform = if ($env:OS -eq "Windows_NT") {
    "Windows"
} elseif ($IsMacOS) {
    "macOS"
} elseif ($IsLinux) {
    "Linux"
} else {
    $PSVersionTable.OS
}

Write-Host "=== Workstation Doctor ===" -ForegroundColor Cyan
Write-Host "Repository: $Root"
Write-Host "Version:    $((Get-Content (Join-Path $Root 'VERSION') -Raw).Trim())"
Write-Host "Platform:   $Platform"
Write-Host ""

foreach ($Tool in @("git","gh","code","oh-my-posh","zoxide","fzf","jq","devcontainer")) {
    $Cmd = Get-Command $Tool -ErrorAction SilentlyContinue
    if ($Cmd) {
        Write-Host ("PASS  {0,-12} {1}" -f $Tool, $Cmd.Source)
    } else {
        Write-Warning ("MISS  {0}" -f $Tool)
    }
}

# Security/research tools install into ~/.local/bin on WSL/Linux/macOS only
# (Windows dispatches "workstation security/research" into WSL rather than
# installing anything natively - see docs/security-scanning.md and
# docs/research-computing.md) - only check them here, not on native Windows,
# to avoid a misleading MISS for tools that were never meant to exist there.
if ($env:OS -ne "Windows_NT") {
    $env:PATH = "$HOME/.local/bin:$env:PATH"
    Write-Host ""
    Write-Host "Security/research toolchain (workstation security/research doctor for detail):"
    foreach ($Tool in @("semgrep","gitleaks","trufflehog","trivy","grype","syft","cosign","conftest","checkov","pdflatex","biber","latexmk","pandoc","quarto","pixi")) {
        $Cmd = Get-Command $Tool -ErrorAction SilentlyContinue
        if ($Cmd) {
            Write-Host ("PASS  {0,-12} {1}" -f $Tool, $Cmd.Source)
        } else {
            Write-Host ("MISS  {0,-12} run: workstation security|research install (or re-run bootstrap)" -f $Tool)
        }
    }
}

if ($env:OS -eq "Windows_NT") {
    Write-Host ""
    Write-Host "PowerShell:"
    Write-Host "  Version:      $($PSVersionTable.PSVersion)"
    Write-Host "  LanguageMode: $($ExecutionContext.SessionState.LanguageMode)"
    Write-Host "  Profile:      $PROFILE"

    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        Write-Host ""
        ((wsl.exe --list --verbose 2>$null) -join "`n") -replace "`0", "" | Write-Host
    }

    Write-Host ""
    Write-Host "Background automation:"
    foreach ($TaskName in @("WorkstationSetupAutoSync", "WorkstationAutoUpgrade")) {
        $Info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction SilentlyContinue
        if (-not $Info) {
            Write-Host ("MISS  {0,-24} not installed" -f $TaskName)
            continue
        }

        # Task Scheduler result codes are signed 32-bit values surfaced as
        # unsigned; 0 is success.
        if ($Info.LastTaskResult -eq 0) {
            Write-Host ("PASS  {0,-24} last run {1}" -f $TaskName, $Info.LastRunTime)
        } else {
            Write-Warning ("FAIL  {0} last run {1} result 0x{2:X8} (next: {3})" `
                -f $TaskName, $Info.LastRunTime, $Info.LastTaskResult, $Info.NextRunTime)
        }
    }
} else {
    Write-Host ""
    Write-Host "Background automation:"

    if ($IsLinux) {
        foreach ($Unit in @("workstation-autosync.timer", "workstation-autoupgrade.timer")) {
            $Active = & systemctl --user is-active $Unit 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host ("MISS  {0,-32} not installed" -f $Unit)
                continue
            }
            $LastResult = & systemctl --user show ($Unit -replace '\.timer$', '.service') `
                --property=Result --value 2>$null
            if ($LastResult -eq "success" -or -not $LastResult) {
                Write-Host ("PASS  {0,-32} {1}" -f $Unit, $Active)
            } else {
                Write-Warning ("FAIL  {0} last result: {1}" -f $Unit, $LastResult)
            }
        }
    } elseif ($IsMacOS) {
        foreach ($Label in @("com.workstation.autosync", "com.workstation.autoupgrade")) {
            $Status = & launchctl list $Label 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host ("MISS  {0,-32} not installed" -f $Label)
            } else {
                Write-Host ("PASS  {0,-32} loaded" -f $Label)
            }
        }
    }
}

Write-Host ""
Write-Host "Cross-domain status (the single view a fully-fledged workstation needs -"
Write-Host "security/research/capacity/labs/templates, not just tool presence):"

# --- Security scan freshness ---
$ScanState = Join-Path $Root ".state\security\last-scan.json"
if (Test-Path $ScanState) {
    $Scan = Get-Content $ScanState -Raw | ConvertFrom-Json
    # ConvertFrom-Json already turns an ISO-8601 "...Z" string into a correctly
    # UTC-kinded [datetime] - found live that re-parsing it via
    # [datetime]::Parse() implicitly stringifies it first using the current
    # culture's month/day order, then reparses that ambiguous string under a
    # different rule, silently swapping month and day (12 Sep <-> 9 Dec) and
    # reporting the scan as 88 days old when it was seconds old. Use the
    # value ConvertFrom-Json already produced correctly instead of touching it.
    $Age = (Get-Date).ToUniversalTime() - $Scan.scannedAtUtc
    $AgeDays = [math]::Floor($Age.TotalDays)
    $State = if ($AgeDays -le 14) { "PASS" } else { "WARN" }
    Write-Host ("{0}  {1,-18} {2}d ago against '{3}', {4} tool(s) reported findings" `
        -f $State, "security scan", $AgeDays, $Scan.target, $Scan.findingsCount)
} else {
    Write-Host ("{0}  {1,-18} never run - workstation security scan ." -f "WARN", "security scan")
}

# --- Capacity ---
if ($env:OS -eq "Windows_NT") {
    $SystemDrive = Get-PSDrive -Name ($Root.Path.Substring(0,1)) -ErrorAction SilentlyContinue
    if ($SystemDrive) {
        $FreePct = [math]::Round(($SystemDrive.Free / ($SystemDrive.Used + $SystemDrive.Free)) * 100)
        $DiskState = if ($FreePct -lt 10) { "WARN" } else { "PASS" }
        Write-Host ("{0}  {1,-18} {2}% free on {3}:" -f $DiskState, "disk", $FreePct, $SystemDrive.Name)
    }
    $Os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
    if ($Os) {
        $FreeMemMB = [math]::Round($Os.FreePhysicalMemory / 1024)
        $MemState = if ($FreeMemMB -lt 512) { "WARN" } else { "PASS" }
        Write-Host ("{0}  {1,-18} {2} MB free" -f $MemState, "memory", $FreeMemMB)
    }
} else {
    $DiskLine = (df -k $Root.Path 2>$null | Select-Object -Last 1) -split '\s+'
    if ($DiskLine.Count -ge 5) {
        $FreePct = 100 - [int]($DiskLine[4] -replace '%', '')
        $DiskState = if ($FreePct -lt 10) { "WARN" } else { "PASS" }
        Write-Host ("{0}  {1,-18} {2}% free" -f $DiskState, "disk", $FreePct)
    }
    if ($IsLinux) {
        $MemLine = (free -m 2>$null | Select-String "^Mem:") -replace '\s+', ' '
        if ($MemLine) {
            $Fields = "$MemLine".Split(' ')
            if ($Fields.Count -ge 7) {
                $FreeMemMB = [int]$Fields[6]
                $MemState = if ($FreeMemMB -lt 512) { "WARN" } else { "PASS" }
                Write-Host ("{0}  {1,-18} {2} MB available" -f $MemState, "memory", $FreeMemMB)
            }
        }
    }
}

# --- Labs currently up ---
if (Get-Command k3d -ErrorAction SilentlyContinue) {
    $Clusters = & k3d cluster list --no-headers 2>$null
    if ($Clusters) {
        Write-Host ("PASS  {0,-18} k3d cluster(s) present - workstation lab status <name>" -f "labs")
    } else {
        Write-Host ("INFO  {0,-18} no k3d clusters (workstation lab list)" -f "labs")
    }
}

# --- Dev-service drift against development/catalog.json ---
# Docker only exists inside WSL on this architecture (docs/adr/0002) - this
# doctor.ps1 process itself runs as native Windows pwsh, so dispatch through
# wsl.exe rather than assume docker is somehow on the Windows PATH.
if ($env:OS -eq "Windows_NT") {
    if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
        $DriftPolicy = Get-Content (Join-Path $Root "policy\development.json") -Raw | ConvertFrom-Json
        $DriftDistro = $DriftPolicy.windows.wslDistribution
        $RunningCount = (wsl.exe -d $DriftDistro -- bash -lc 'docker ps --filter "name=^dev-" --format "{{.Names}}" 2>/dev/null | wc -l' 2>$null | Select-Object -Last 1)
        if ($RunningCount -and [int]$RunningCount -gt 0) {
            wsl.exe -d $DriftDistro -- bash -lc 'workstation drift-check' *> $null
            if ($LASTEXITCODE -eq 0) {
                Write-Host ("PASS  {0,-18} {1} running dev-service(s), none drifted from development/catalog.json" -f "drift", $RunningCount)
            } else {
                Write-Host ("WARN  {0,-18} running dev-service(s) don't match development/catalog.json - workstation drift-check" -f "drift")
            }
        }
    }
} elseif (Get-Command docker -ErrorAction SilentlyContinue) {
    $RunningCount = (docker ps --filter "name=^dev-" --format "{{.Names}}" 2>$null | Measure-Object -Line).Lines
    if ($RunningCount -gt 0) {
        & bash (Join-Path $Root "scripts/posix/drift-check.sh") *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host ("PASS  {0,-18} {1} running dev-service(s), none drifted from development/catalog.json" -f "drift", $RunningCount)
        } else {
            Write-Host ("WARN  {0,-18} running dev-service(s) don't match development/catalog.json - workstation drift-check" -f "drift")
        }
    }
}

# --- Template drift across every governed project this machine knows about ---
$TemplateCatalogPath = Join-Path $Root "templates\catalog.json"
$PolicyPath = Join-Path $Root "policy\development.json"
if ((Test-Path $TemplateCatalogPath) -and (Test-Path $PolicyPath)) {
    $Catalog = (Get-Content $TemplateCatalogPath -Raw | ConvertFrom-Json).templates
    $Policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
    $Outdated = 0
    $Total = 0
    foreach ($ProjRootRaw in $Policy.projectRoots) {
        $ProjRoot = $ProjRootRaw -replace '^~', $HOME
        if (-not (Test-Path $ProjRoot)) { continue }
        Get-ChildItem -Path $ProjRoot -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $MetaPath = Join-Path $_.FullName ".platformctl\project.json"
            if (Test-Path $MetaPath) {
                $Total++
                $Meta = Get-Content $MetaPath -Raw | ConvertFrom-Json
                $Entry = $Catalog.($Meta.template)
                if ($Entry -and $Meta.templateVersion -ne $Entry.version) { $Outdated++ }
            }
        }
    }
    if ($Total -gt 0) {
        $TplState = if ($Outdated -gt 0) { "WARN" } else { "PASS" }
        Write-Host ("{0}  {1,-18} {2}/{3} project(s) on an outdated template version" `
            -f $TplState, "templates", $Outdated, $Total)
    }
}

Write-Host ""
git -C $Root status --short
