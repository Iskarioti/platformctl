[CmdletBinding()]
param(
    [Parameter(Position=0)]
    [string]$Action = "help",

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

if ($env:OS -eq "Windows_NT") {
    $Policy = Get-Content (Join-Path $Root "policy\development.json") -Raw | ConvertFrom-Json
    $Distro = $Policy.windows.wslDistribution

    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        throw "WSL is required for model-runtime commands on Windows."
    }

    $RepoLinux = (
        wsl.exe -d $Distro -- wslpath -a -u $Root.Path 2>$null |
        Select-Object -First 1
    )

    if (-not $RepoLinux) {
        throw "Could not translate the platformctl repository path into WSL."
    }

    $Dispatcher = "$RepoLinux/scripts/posix/models.sh"
    wsl.exe -d $Distro -- bash $Dispatcher $Action @Rest
    exit $LASTEXITCODE
}

& bash (Join-Path $Root "scripts/posix/models.sh") $Action @Rest
exit $LASTEXITCODE
