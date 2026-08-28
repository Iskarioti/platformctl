param([switch]$Hook)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Write-Host "Validating workstation repository..."

# JSON syntax.
Get-ChildItem $Root -Recurse -File -Filter *.json | ForEach-Object {
    try {
        Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null
    } catch {
        throw "Invalid JSON: $($_.FullName)`n$($_.Exception.Message)"
    }
}

# Hard invariants.
$Config = Get-Content (Join-Path $Root "workstation.json") -Raw | ConvertFrom-Json
if ($Config.copyStrategy -ne "cp") { throw "copyStrategy must remain cp." }
if ($Config.fonts.editor.family -ne "JetBrains Mono") { throw "Editor font must be JetBrains Mono." }
if ($Config.fonts.terminal.family -ne "JetBrainsMono Nerd Font Mono") { throw "Terminal font invariant failed." }

$WT = Get-Content (Join-Path $Root "windows-terminal\settings.json") -Raw | ConvertFrom-Json
$ExpectedGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
if ($WT.defaultProfile -ne $ExpectedGuid) { throw "Unexpected Windows Terminal default profile." }
if ($WT.profiles.list.Count -ne 1) { throw "Windows Terminal must expose exactly one explicit profile." }

# No font binaries are committed.
$FontFiles = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.Extension -in @(".ttf",".otf",".woff",".woff2")
}
if ($FontFiles) { throw "Font binaries must not be committed." }

# No obvious private key files.
$Forbidden = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.Name -match '^(id_rsa|id_ed25519)$' -or
    $_.Extension -in @(".pfx",".p12",".kdbx")
}
if ($Forbidden) { throw "Forbidden secret-like files are present." }

# rsync is explicitly forbidden in the managed source.
$TextFiles = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.Extension -in @(".ps1",".sh",".md",".json",".yml",".yaml",".txt") -or
    $_.Name -in @("bootstrap","setup","AGENTS.md","CLAUDE.md","KIMI.md")
}
foreach ($File in $TextFiles) {
    $Text = Get-Content $File.FullName -Raw -ErrorAction SilentlyContinue
    if ($Text -match '(?im)^\s*rsync\b') {
        throw "rsync command found in $($File.FullName). Use cp/Copy-Item."
    }
}

Write-Host "PASS repository validation" -ForegroundColor Green
