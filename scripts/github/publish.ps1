param(
    [Parameter(Position=0)]
    [string]$Repository = "Iskarioti/system-platform-architect-workstation",

    [ValidateSet("private","public")]
    [string]$Visibility = "private"
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
Set-Location $Root

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) is required."
}

gh auth status
if ($LASTEXITCODE -ne 0) {
    throw "Authenticate GitHub CLI first with: gh auth login"
}

git remote get-url origin 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "origin already exists: $(git remote get-url origin)"
    exit 0
}

$Flag = if ($Visibility -eq "public") { "--public" } else { "--private" }

gh repo create $Repository $Flag --source . --remote origin --push
if ($LASTEXITCODE -ne 0) {
    throw "GitHub repository publish failed."
}

Write-Host "Published $Repository and configured origin."
