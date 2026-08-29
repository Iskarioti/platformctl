param([switch]$Hook)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

Write-Host "Validating workstation repository..."

function Assert-File {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Message)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw $Message }
}

function Assert-Directory {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Message)
    if (-not (Test-Path -LiteralPath $Path -PathType Container)) { throw $Message }
}

Get-ChildItem $Root -Recurse -File -Filter *.json | ForEach-Object {
    try { Get-Content $_.FullName -Raw | ConvertFrom-Json | Out-Null }
    catch { throw "Invalid JSON: $($_.FullName)`n$($_.Exception.Message)" }
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
Assert-File -Path $PolicyPath -Message "Development policy does not exist: $PolicyPath"
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
    Assert-Directory -Path $TemplateRoot -Message "Approved project template is missing: $Template"

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

# Modular development service catalog.
$ServicePolicy = $Policy.developmentServices
if (-not $ServicePolicy.enabled) { throw "Development service catalog must remain enabled." }
if ($ServicePolicy.autoStartAfterBootstrap) { throw "Development services must remain opt-in after bootstrap." }
if ($ServicePolicy.network -ne "platform-dev") { throw "Development service network invariant failed." }
if ($ServicePolicy.catalog -ne "development/catalog.json") {
    throw "developmentServices.catalog must point to development/catalog.json."
}

$CatalogPath = Join-Path $Root $ServicePolicy.catalog
Assert-File -Path $CatalogPath -Message "Modular development service catalog is missing: $CatalogPath"

$Catalog = Get-Content $CatalogPath -Raw | ConvertFrom-Json
if ($Catalog.network -ne "platform-dev") { throw "Modular service catalog network invariant failed." }
if ($Catalog.bindAddress -ne "127.0.0.1") { throw "Development services must bind to 127.0.0.1." }

$CatalogServiceNames = @($Catalog.services.PSObject.Properties.Name)

foreach ($Service in $ServicePolicy.allowedServices) {
    if ($CatalogServiceNames -notcontains $Service) {
        throw "Allowed development service is missing from development/catalog.json: $Service"
    }

    $Entry = $Catalog.services.$Service
    if (-not $Entry.path) { throw "Catalog service '$Service' has no path." }

    $ServiceRoot = Join-Path $Root $Entry.path
    Assert-Directory -Path $ServiceRoot -Message "Service directory is missing: $ServiceRoot"

    foreach ($Required in @(
        "service.json","versions.env","defaults.env",".env.example","compose.yaml","README.md"
    )) {
        Assert-File -Path (Join-Path $ServiceRoot $Required) `
            -Message "Service '$Service' is missing required file: $Required"
    }

    $Meta = Get-Content (Join-Path $ServiceRoot "service.json") -Raw | ConvertFrom-Json
    if ($Meta.id -ne $Service) { throw "Service metadata id mismatch for '$Service': $($Meta.id)" }

    foreach ($Dependency in @($Meta.dependsOn)) {
        if ($CatalogServiceNames -notcontains $Dependency) {
            throw "Service '$Service' depends on unknown service '$Dependency'."
        }
    }

    $VersionsText = Get-Content (Join-Path $ServiceRoot "versions.env") -Raw
    if ($VersionsText -match '(?im)_VERSION\s*=\s*latest\s*$') {
        throw "Service '$Service' uses a latest version tag."
    }

    $ComposeText = Get-Content (Join-Path $ServiceRoot "compose.yaml") -Raw
    if ($ComposeText -match '(?im)^\s*image:\s*[^\r\n]+:latest\s*$') {
        throw "Service '$Service' uses Docker :latest."
    }

    foreach ($Line in ($ComposeText -split "`n")) {
        if ($Line -match '^\s*-\s*["'']?[^"'']*:\d+:\d+["'']?\s*$' -and $Line -notmatch '127\.0\.0\.1:') {
            throw "Published port for '$Service' must bind to 127.0.0.1: $Line"
        }
    }
}

foreach ($ProfileProperty in $Catalog.profiles.PSObject.Properties) {
    foreach ($Service in @($ProfileProperty.Value)) {
        if ($CatalogServiceNames -notcontains $Service) {
            throw "Profile '$($ProfileProperty.Name)' references unknown service '$Service'."
        }
    }
}

foreach ($Script in @("scripts\posix\services.sh","scripts\common\services.ps1")) {
    Assert-File -Path (Join-Path $Root $Script) -Message "Development service dispatcher is missing: $Script"
}

foreach ($Legacy in @(
    "development\services\compose.yaml",
    "development\services\versions.env",
    "development\services\.env.example"
)) {
    if (Test-Path -LiteralPath (Join-Path $Root $Legacy) -PathType Leaf) {
        throw "Legacy monolithic service catalog file must remain retired: $Legacy"
    }
}

# Architecture labs.
if (-not $Policy.labs.enabled) { throw "Architecture labs must remain enabled." }
if ($Policy.labs.productionPromotion -ne "iac-only") { throw "Lab promotion boundary must remain iac-only." }
if ($Policy.labs.kubernetesProvider -ne "k3d") { throw "Local Kubernetes lab provider must remain k3d." }

$LabsCatalogPath = Join-Path $Root $Policy.labs.catalog
Assert-File -Path $LabsCatalogPath -Message "Labs catalog is missing: $LabsCatalogPath"

$LabsCatalog = Get-Content $LabsCatalogPath -Raw | ConvertFrom-Json

foreach ($LabProperty in $LabsCatalog.labs.PSObject.Properties) {
    $LabName = $LabProperty.Name
    $Lab = $LabProperty.Value
    $LabRoot = Join-Path $Root $Lab.path

    Assert-Directory -Path $LabRoot -Message "Lab directory is missing: $LabName"
    Assert-File -Path (Join-Path $LabRoot "lab.json") -Message "Lab '$LabName' is missing lab.json."

    foreach ($Runtime in @($Lab.runtimes)) {
        switch ($Runtime) {
            "docker" {
                Assert-File -Path (Join-Path $LabRoot "docker\compose.yaml") `
                    -Message "Lab '$LabName' is missing Docker compose.yaml."
            }
            "kubernetes" {
                Assert-File -Path (Join-Path $LabRoot "kubernetes\kustomization.yaml") `
                    -Message "Lab '$LabName' is missing Kubernetes kustomization.yaml."
            }
            default { throw "Lab '$LabName' declares unsupported runtime '$Runtime'." }
        }
    }

    $LabYamlFiles = Get-ChildItem $LabRoot -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Extension -in @(".yml",".yaml") }

    foreach ($LabYaml in $LabYamlFiles) {
        $Text = Get-Content $LabYaml.FullName -Raw
        if ($Text -match '(?im)^\s*image:\s*[^\r\n]+:latest\s*$') {
            throw "Lab '$LabName' contains Docker/Kubernetes :latest image: $($LabYaml.FullName)"
        }
    }
}

foreach ($Script in @(
    "scripts\posix\labs.sh",
    "scripts\posix\install-lab-toolchain.sh",
    "scripts\common\labs.ps1"
)) {
    Assert-File -Path (Join-Path $Root $Script) -Message "Lab component is missing: $Script"
}

Write-Host "PASS repository validation" -ForegroundColor Green
