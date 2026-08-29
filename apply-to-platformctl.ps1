#Requires -Version 7.0
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$Overlay = Join-Path $PackageRoot "overlay"
$RepoPath = (Resolve-Path -LiteralPath $RepoPath).Path

if (-not (Test-Path -LiteralPath (Join-Path $RepoPath "setup.ps1"))) {
    throw "Not a platformctl repository: $RepoPath"
}

$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = Join-Path $RepoPath ".state\modular-services-labs-backup-$Stamp"
New-Item -ItemType Directory -Force -Path $Backup | Out-Null

function Backup-File {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    $Relative = [IO.Path]::GetRelativePath($RepoPath, $Path)
    $Target = Join-Path $Backup $Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Target) | Out-Null
    Copy-Item -LiteralPath $Path -Destination $Target -Force
}

# Back up old monolithic service files before retiring them.
foreach ($Relative in @(
    "development\services\compose.yaml",
    "development\services\versions.env",
    "development\services\.env.example",
    "scripts\posix\services.sh",
    "scripts\ci\validate.ps1",
    "policy\development.json",
    "schema\development-policy.schema.json",
    "setup",
    "setup.ps1",
    "scripts\posix\workstation.sh",
    "platform\linux\bootstrap.sh"
)) {
    Backup-File -Path (Join-Path $RepoPath $Relative)
}

Write-Host "=== Installing modular services + lab framework ===" -ForegroundColor Cyan

Get-ChildItem -LiteralPath $Overlay -Recurse -Force -File | ForEach-Object {
    $Relative = [IO.Path]::GetRelativePath($Overlay, $_.FullName)
    $Destination = Join-Path $RepoPath $Relative
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Destination) | Out-Null
    Copy-Item -LiteralPath $_.FullName -Destination $Destination -Force
    Unblock-File -LiteralPath $Destination -ErrorAction SilentlyContinue
}

# Retire monolithic service files; canonical config is now per-service.
foreach ($Relative in @(
    "development\services\compose.yaml",
    "development\services\versions.env",
    "development\services\.env.example"
)) {
    $Path = Join-Path $RepoPath $Relative
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force
    }
}

# Merge development policy instead of replacing local policy choices.
$PolicyPath = Join-Path $RepoPath "policy\development.json"
$Policy = Get-Content -LiteralPath $PolicyPath -Raw | ConvertFrom-Json
$Policy.version = "1.2.0"

$Policy.developmentServices.catalog = "development/catalog.json"
$Policy.developmentServices.credentialsFile = "~/.config/workstation/services"
$Policy.developmentServices.allowedServices = @(
    "postgres","pgbouncer","pgadmin",
    "redis","redisinsight",
    "kafka","kafbat-ui",
    "opensearch","opensearch-dashboards",
    "rabbitmq","mongodb","minio","mailpit","dev-dashboard"
)
$Policy.developmentServices.profiles = [ordered]@{
    core        = @("postgres","redis")
    messaging   = @("kafka","rabbitmq")
    search      = @("opensearch")
    data        = @("postgres","pgbouncer","mongodb")
    integration = @("minio","mailpit")
    ui          = @("dev-dashboard","pgadmin","redisinsight","kafbat-ui","opensearch-dashboards")
    all         = @(
        "postgres","pgbouncer","pgadmin",
        "redis","redisinsight",
        "kafka","kafbat-ui",
        "opensearch","opensearch-dashboards",
        "rabbitmq","mongodb","minio","mailpit","dev-dashboard"
    )
}

$Labs = [ordered]@{
    enabled = $true
    catalog = "labs/catalog.json"
    stateRoot = "~/.local/state/platformctl/labs"
    defaultRuntime = "docker"
    kubernetesProvider = "k3d"
    kubernetesCluster = "platform-labs"
    productionPromotion = "iac-only"
}

if ($null -eq $Policy.PSObject.Properties["labs"]) {
    $Policy | Add-Member -NotePropertyName labs -NotePropertyValue $Labs
} else {
    $Policy.labs = $Labs
}

$Policy | ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $PolicyPath -Encoding utf8

# Extend schema with the labs object, preserving the schema's permissive design.
$SchemaPath = Join-Path $RepoPath "schema\development-policy.schema.json"
$Schema = Get-Content -LiteralPath $SchemaPath -Raw | ConvertFrom-Json
if (-not ($Schema.required -contains "labs")) {
    $Schema.required += "labs"
}
$LabsSchema = [ordered]@{
    type = "object"
    required = @("enabled","catalog","stateRoot","defaultRuntime","kubernetesProvider","kubernetesCluster","productionPromotion")
    properties = [ordered]@{
        enabled = @{ type = "boolean" }
        catalog = @{ type = "string" }
        stateRoot = @{ type = "string" }
        defaultRuntime = @{ type = "string"; enum = @("docker","kubernetes") }
        kubernetesProvider = @{ type = "string" }
        kubernetesCluster = @{ type = "string" }
        productionPromotion = @{ type = "string" }
    }
}
if ($null -eq $Schema.properties.PSObject.Properties["labs"]) {
    $Schema.properties | Add-Member -NotePropertyName labs -NotePropertyValue $LabsSchema
} else {
    $Schema.properties.labs = $LabsSchema
}
$Schema | ConvertTo-Json -Depth 20 |
    Set-Content -LiteralPath $SchemaPath -Encoding utf8

# Patch POSIX top-level setup.
$SetupPath = Join-Path $RepoPath "setup"
$Text = Get-Content -LiteralPath $SetupPath -Raw
if ($Text -notmatch 'services\|lab\|editor') {
    $Text = $Text.Replace(
        "validate|doctor|enforce|project|services|editor|sync|publish|autosync|update|dry-run|help)",
        "validate|doctor|enforce|project|services|lab|editor|sync|publish|autosync|update|dry-run|help)"
    )
}
Set-Content -LiteralPath $SetupPath -Value $Text -Encoding utf8

# Patch POSIX workstation dispatcher.
$WorkstationPath = Join-Path $RepoPath "scripts\posix\workstation.sh"
$Text = Get-Content -LiteralPath $WorkstationPath -Raw
if ($Text -notmatch '(?m)^\s*lab\)') {
    $Anchor = '  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;'
    $Insert = $Anchor + "`n" + '  lab) exec "$ROOT/scripts/posix/labs.sh" "$@" ;;'
    if (-not $Text.Contains($Anchor)) { throw "Could not patch lab dispatcher." }
    $Text = $Text.Replace($Anchor, $Insert)
}
if ($Text -notmatch 'lab list\|info\|toolchain') {
    $Anchor = "  services reset <service> [--yes]`n"
    $Insert = $Anchor + "  lab list|info|toolchain|cluster|up|status|logs|test|stop|destroy|report`n"
    $Text = $Text.Replace($Anchor, $Insert)
}
Set-Content -LiteralPath $WorkstationPath -Value $Text -Encoding utf8

# Patch PowerShell setup dispatcher.
$SetupPs1 = Join-Path $RepoPath "setup.ps1"
$Text = Get-Content -LiteralPath $SetupPs1 -Raw
if ($Text -notmatch '(?m)^\s*"lab"\s*\{') {
    $Anchor = '    "editor" {'
    $Block = @'
    "lab" {
        if ($IsWindows -or $env:OS -eq "Windows_NT") {
            Invoke-RepoScript -Path "scripts\common\labs.ps1" -Arguments @($Rest)
        } else {
            & bash (Join-Path $Root "scripts/posix/labs.sh") @Rest
            exit $LASTEXITCODE
        }
    }

'@
    if (-not $Text.Contains($Anchor)) { throw "Could not patch setup.ps1 lab dispatcher." }
    $Text = $Text.Replace($Anchor, $Block + $Anchor)
}
if ($Text -notmatch 'lab list\|info\|toolchain') {
    $Anchor = "  services down                     stop catalog containers, preserve data`n"
    $Text = $Text.Replace(
        $Anchor,
        $Anchor + "  lab list|info|toolchain|up|test  run isolated Docker/Kubernetes architecture labs`n"
    )
}
Set-Content -LiteralPath $SetupPs1 -Value $Text -Encoding utf8

# Patch Linux bootstrap to install lab CLIs, but do not create clusters or start labs.
$Bootstrap = Join-Path $RepoPath "platform\linux\bootstrap.sh"
$Text = Get-Content -LiteralPath $Bootstrap -Raw

if ($Text -notmatch 'NO_LAB_TOOLS') {
    $Text = $Text.Replace(
        'NO_AUTOSYNC=0',
        "NO_AUTOSYNC=0`nNO_LAB_TOOLS=0"
    )
    $Text = $Text.Replace(
        '[[ "$arg" == "--no-autosync" ]] && NO_AUTOSYNC=1',
        "[[ `"`$arg`" == `"--no-autosync`" ]] && NO_AUTOSYNC=1`n  [[ `"`$arg`" == `"--no-lab-tools`" ]] && NO_LAB_TOOLS=1"
    )
}

if ($Text -notmatch 'install-lab-toolchain\.sh') {
    $Anchor = '"$ROOT/platform/linux/install-docker.sh"'
    $Insert = @'
"$ROOT/platform/linux/install-docker.sh"

if [[ "$NO_LAB_TOOLS" -eq 0 ]]; then
  "$ROOT/scripts/posix/install-lab-toolchain.sh"
fi
'@
    if (-not $Text.Contains($Anchor)) { throw "Could not patch Linux bootstrap for lab tools." }
    $Text = $Text.Replace($Anchor, $Insert.TrimEnd())
}

Set-Content -LiteralPath $Bootstrap -Value $Text -Encoding utf8

# Unblock trusted repo files after deliberate install.
Get-ChildItem -LiteralPath $RepoPath -Recurse -Force -File -ErrorAction SilentlyContinue |
    ForEach-Object {
        Unblock-File -LiteralPath $_.FullName -ErrorAction SilentlyContinue
    }

Write-Host ""
Write-Host "platformctl v3.5.0 modular services + labs update applied." -ForegroundColor Green
Write-Host "Backup: $Backup"
Write-Host ""
Write-Host "Validate:"
Write-Host '  pwsh.exe -NoLogo -NoProfile -File ".\setup.ps1" validate'
Write-Host ""
Write-Host "Inside WSL:"
Write-Host '  workstation services list'
Write-Host '  workstation services doctor'
Write-Host '  workstation lab toolchain doctor'
Write-Host '  workstation lab list'
