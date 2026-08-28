#Requires -Version 7.0
[CmdletBinding()]
param([switch]$Force)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..")
$Config = Get-Content (Join-Path $Root "workstation.json") -Raw | ConvertFrom-Json
$Version = $Config.fonts.editor.version

Write-Host "=== Fonts ===" -ForegroundColor Cyan
Write-Host "Editor:   JetBrains Mono $Version (official JetBrains release)"
Write-Host "Terminal: JetBrainsMono Nerd Font Mono"

$Temp = Join-Path $env:TEMP "workstation-fonts"
New-Item -ItemType Directory -Path $Temp -Force | Out-Null

# Official JetBrains Mono release archive.
$Archive = Join-Path $Temp "JetBrainsMono.zip"
$Url = "https://github.com/JetBrains/JetBrainsMono/releases/download/v$Version/JetBrainsMono-$Version.zip"
curl.exe -fL $Url -o $Archive
if ($LASTEXITCODE -ne 0) { throw "Failed to download official JetBrains Mono." }

$Extract = Join-Path $Temp "jetbrainsmono"
if (Test-Path $Extract) { Remove-Item $Extract -Recurse -Force }
Expand-Archive -Path $Archive -DestinationPath $Extract -Force

# Install official JetBrains Mono per-user to avoid requiring admin rights.
$UserFonts = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
New-Item -ItemType Directory -Path $UserFonts -Force | Out-Null

$Fonts = Get-ChildItem (Join-Path $Extract "fonts\ttf") -Filter "JetBrainsMono-*.ttf"
foreach ($Font in $Fonts) {
    $Target = Join-Path $UserFonts $Font.Name
    Copy-Item $Font.FullName $Target -Force

    # Register for current user using native registry tooling.
    $RegName = "$($Font.BaseName) (TrueType)"
    reg.exe add "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" `
        /v $RegName /t REG_SZ /d $Target /f | Out-Null
}

# Nerd Font terminal family through the NerdFonts module.
if (-not (Get-Module -ListAvailable -Name NerdFonts)) {
    Write-Host "Installing NerdFonts PowerShell resource..."
    Write-Host "If PSGallery is untrusted, approve the repository prompt interactively."
    Install-PSResource -Name NerdFonts -Scope CurrentUser
}

Import-Module NerdFonts -ErrorAction Stop

# Prefer all-users when elevated; gracefully use CurrentUser otherwise.
& fltmc.exe > $null 2>&1
$Elevated = ($LASTEXITCODE -eq 0)

if ($Elevated) {
    Install-NerdFont -Name 'JetBrainsMono' -Variant Mono -Scope AllUsers -Force:$Force
} else {
    Install-NerdFont -Name 'JetBrainsMono' -Variant Mono -Scope CurrentUser -Force:$Force
}

Write-Host "Font installation complete." -ForegroundColor Green
