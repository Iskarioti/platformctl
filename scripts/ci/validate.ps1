param([switch]$Hook)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Write-Host "Validating workstation repository..."

Get-ChildItem $Root -Recurse -File -Filter *.json | ForEach-Object {
    try {
        Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null
    } catch {
        throw "Invalid JSON: $($_.FullName)`n$($_.Exception.Message)"
    }
}

$Config = Get-Content (Join-Path $Root "workstation.json") -Raw | ConvertFrom-Json
if ($Config.copyStrategy -ne "cp") { throw "copyStrategy must remain cp." }
if ($Config.fonts.editor.family -ne "JetBrains Mono") { throw "Editor font must be JetBrains Mono." }
if ($Config.fonts.terminal.family -ne "JetBrainsMono Nerd Font Mono") { throw "Terminal font invariant failed." }
if ($Config.safeTrackedRoots -notcontains "policy") { throw "policy must remain an autosync-safe tracked root." }

$WT = Get-Content (Join-Path $Root "windows-terminal\settings.json") -Raw | ConvertFrom-Json
$ExpectedGuid = "{574e775e-4f2a-5b96-ac1e-a2962a402336}"
if ($WT.defaultProfile -ne $ExpectedGuid) { throw "Unexpected Windows Terminal default profile." }
if ($WT.profiles.list.Count -ne 1) { throw "Windows Terminal must expose exactly one explicit profile." }

$PolicyPath = Join-Path $Root $Config.developmentPolicy
if (-not (Test-Path -LiteralPath $PolicyPath -PathType Leaf)) {
    throw "Development policy does not exist: $PolicyPath"
}

$Policy = Get-Content $PolicyPath -Raw | ConvertFrom-Json
if (-not $Policy.windows.developmentInWSL) { throw "Windows development must remain inside WSL." }
if ($Policy.windows.dockerEngine -ne "wsl") { throw "Docker Engine on Windows must remain inside WSL." }
if ($Policy.windows.dockerDesktopAllowed) { throw "Docker Desktop must not be enabled by development policy." }
if ($Policy.windows.allowProjectsOnWindowsFilesystem) { throw "Windows filesystem project development must remain disabled." }
if (-not $Policy.projects.requireDevContainer) { throw "Dev Containers must remain required." }
if (-not $Policy.security.forbidTrackedEnvFiles) { throw "Tracked .env files must remain forbidden." }
if (-not $Policy.security.forbidPrivateKeys) { throw "Private key tracking must remain forbidden." }
if (-not $Policy.containers.requireNonRootDevContainer) { throw "Non-root Dev Containers must remain required." }
if (-not $Policy.containers.forbidLatestTag) { throw "Docker :latest must remain forbidden." }

foreach ($Template in $Policy.projects.allowedTemplates) {
    $TemplateRoot = Join-Path $Root "templates\projects\$Template"
    if (-not (Test-Path -LiteralPath $TemplateRoot -PathType Container)) {
        throw "Approved project template is missing: $Template"
    }

    foreach ($Required in @(
        ".devcontainer\devcontainer.json",
        ".editorconfig",
        ".gitignore",
        ".env.example",
        "README.md",
        ".github\workflows\ci.yml",
        ".github\workflows\policy.yml"
    )) {
        if (-not (Test-Path -LiteralPath (Join-Path $TemplateRoot $Required))) {
            throw "Template '$Template' is missing required file: $Required"
        }
    }

    $DevContainer = Get-Content (Join-Path $TemplateRoot ".devcontainer\devcontainer.json") -Raw | ConvertFrom-Json
    if (-not $DevContainer.remoteUser -or $DevContainer.remoteUser -eq "root") {
        throw "Template '$Template' must use a non-root devcontainer remoteUser."
    }
}

$FontFiles = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.Extension -in @(".ttf",".otf",".woff",".woff2")
}
if ($FontFiles) { throw "Font binaries must not be committed." }

$Forbidden = Get-ChildItem $Root -Recurse -File | Where-Object {
    $_.Name -match '^(id_rsa|id_ed25519)$' -or
    $_.Extension -in @(".pfx",".p12",".kdbx")
}
if ($Forbidden) { throw "Forbidden secret-like files are present." }

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

$DockerFiles = Get-ChildItem (Join-Path $Root "templates\projects") -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq "Dockerfile" -or $_.Name -like "Dockerfile.*" }

foreach ($DockerFile in $DockerFiles) {
    $Text = Get-Content $DockerFile.FullName -Raw
    if ($Text -match '(?im)^\s*FROM\s+\S+:latest(?:\s|$)') {
        throw "Docker :latest is forbidden in template: $($DockerFile.FullName)"
    }
}

Write-Host "PASS repository validation" -ForegroundColor Green
