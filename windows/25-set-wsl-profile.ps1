param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("default","ai-lab")]
    [string]$Profile
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$Source = Join-Path $Root "wsl\profiles\$Profile.wslconfig"
$Destination = Join-Path $env:USERPROFILE ".wslconfig"

Copy-Item $Source $Destination -Force
Write-Host "Applied WSL profile: $Profile"
Get-Content $Destination

Write-Host "Stopping WSL so the new limits take effect..."
wsl --shutdown
