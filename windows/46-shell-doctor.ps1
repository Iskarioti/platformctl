#Requires -Version 7.0
$ErrorActionPreference = "Continue"

Write-Host "=== PowerShell / Terminal doctor ===" -ForegroundColor Cyan
Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
Write-Host "Edition:    $($PSVersionTable.PSEdition)"
Write-Host "Profile:    $PROFILE"
Write-Host "Language:   $($ExecutionContext.SessionState.LanguageMode)"
Write-Host ""

Write-Host "Execution policy:"
Get-ExecutionPolicy -List
Write-Host ""

Write-Host "Core tools:"
foreach ($Tool in @("pwsh","oh-my-posh","zoxide","fzf","git","az","wsl","code")) {
    $Command = Get-Command $Tool -ErrorAction SilentlyContinue
    if ($Command) {
        Write-Host ("PASS  {0,-12} {1}" -f $Tool, $Command.Source)
    } else {
        Write-Warning ("FAIL  {0}" -f $Tool)
    }
}
Write-Host ""

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    Write-Host "Oh My Posh:"
    oh-my-posh version
    Write-Host "Theme: $HOME\.config\oh-my-posh\tokyonight-architect.omp.json"
}
Write-Host ""

if (Get-Module -ListAvailable -Name NerdFonts) {
    Import-Module NerdFonts -ErrorAction SilentlyContinue
    Write-Host "Meslo AllUsers fonts:"
    Get-Font -Name 'Meslo*' -Scope AllUsers -ErrorAction SilentlyContinue
} else {
    Write-Warning "NerdFonts module not installed; global font state was not checked."
}
Write-Host ""

Write-Host "WSL:"
wsl.exe --list --verbose
