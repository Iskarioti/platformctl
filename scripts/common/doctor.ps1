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
git -C $Root status --short
