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

$Fonts = Get-ChildItem `
    (Join-Path $Extract "fonts\ttf") `
    -Filter "JetBrainsMono-*.ttf"

foreach ($Font in $Fonts) {
    $Target = Join-Path $UserFonts $Font.Name
    $NeedsCopy = $true

    if (Test-Path -LiteralPath $Target) {
        $SourceHash = (
            Get-FileHash `
                -LiteralPath $Font.FullName `
                -Algorithm SHA256
        ).Hash

        $TargetHash = (
            Get-FileHash `
                -LiteralPath $Target `
                -Algorithm SHA256
        ).Hash

        if ($SourceHash -eq $TargetHash) {
            Write-Host "Already installed: $($Font.Name)"
            $NeedsCopy = $false
        }
        else {
            Write-Host "Update required: $($Font.Name)"
        }
    }

    if ($NeedsCopy) {
        try {
            Copy-Item `
                -LiteralPath $Font.FullName `
                -Destination $Target `
                -Force

            Write-Host "Installed: $($Font.Name)"
        }
        catch {
            throw @"
Unable to update font:

  $($Font.Name)

Destination:
  $Target

The existing font differs from JetBrains Mono $Version and is currently
locked by another process.

Close applications using JetBrains Mono, including Windows Terminal,
VS Code and other editors, then rerun the font installer.

Original error:
  $($_.Exception.Message)
"@
        }
    }

    # Ensure current-user registration exists even when the physical
    # font file was already correct.
    $RegName = "$($Font.BaseName) (TrueType)"

    reg.exe add `
        "HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts" `
        /v $RegName `
        /t REG_SZ `
        /d $Target `
        /f |
        Out-Null

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to register font: $($Font.Name)"
    }
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
