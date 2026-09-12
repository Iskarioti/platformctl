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
        throw "WSL is required for security-tooling commands on Windows - governed project code lives under WSL's ~/src/* per policy, and that's where these scanners need to run."
    }

    $RepoLinux = (
        wsl.exe -d $Distro -- wslpath -a -u $Root.Path 2>$null |
        Select-Object -First 1
    )

    if (-not $RepoLinux) {
        throw "Could not translate the platformctl repository path into WSL."
    }

    $Dispatcher = "$RepoLinux/scripts/posix/security.sh"
    wsl.exe -d $Distro -- bash $Dispatcher $Action @Rest
    exit $LASTEXITCODE
}

& bash (Join-Path $Root "scripts/posix/security.sh") $Action @Rest
exit $LASTEXITCODE
