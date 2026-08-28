#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ConfigDir = Join-Path $HOME ".config\workstation"
$BinDir = Join-Path $HOME ".local\bin"
New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

Set-Content -Path (Join-Path $ConfigDir "repo-path") -Value $Root -Encoding utf8

$Cmd = @"
@echo off
for /f "usebackq delims=" %%R in ("%USERPROFILE%\.config\workstation\repo-path") do set "WORKSTATION_REPO=%%R"
pwsh.exe -NoLogo -NoProfile -File "%WORKSTATION_REPO%\setup.ps1" %*
"@
Set-Content -Path (Join-Path $BinDir "workstation.cmd") -Value $Cmd -Encoding ascii

# Add a profile function too, avoiding a permanent PATH mutation on managed endpoints.
$ProfileSource = Join-Path $Root "shell\powershell\Microsoft.PowerShell_profile.ps1"
$Text = Get-Content $ProfileSource -Raw
if ($Text -notmatch 'function workstation') {
    Add-Content $ProfileSource @'

function workstation {
    $RepoPathFile = Join-Path $HOME ".config\workstation\repo-path"
    if (-not (Test-Path $RepoPathFile)) {
        Write-Error "Workstation repo path is not registered."
        return
    }
    $Repo = (Get-Content $RepoPathFile -Raw).Trim()
    & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Repo "setup.ps1") @args
}
'@
}

Write-Host "workstation command installed into the managed PowerShell profile."
