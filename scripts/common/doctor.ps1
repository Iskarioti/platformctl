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

foreach ($Tool in @("git","gh","code","oh-my-posh","zoxide","fzf","jq")) {
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
        wsl.exe --list --verbose
    }
}

Write-Host ""
git -C $Root status --short
