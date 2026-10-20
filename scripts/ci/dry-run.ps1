$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

# Real bug found 2026-10-20, confirmed in actual GitHub Actions run history:
# the bare call-operator form `& (Join-Path ...)` used here previously does
# NOT reliably invoke a .ps1 file by path string in this environment -
# reproduces identically on ubuntu-latest, macos-latest AND a real Windows
# machine (ruling out any single-OS or single-machine cause - e.g. not a
# Windows-only AppLocker/WDAC artifact, which was this repo's first, WRONG
# guess last session). `Get-Command <path>.ps1` fails to resolve the exact
# same path the same way, while `pwsh.exe -File <path>` (the subprocess
# pattern used EVERYWHERE ELSE in this repo - setup.ps1's Invoke-RepoScript,
# platform/windows/bootstrap.ps1's Run function, etc.) succeeds every time
# this was tested. This one-line bug silently broke `validate`'s macOS/Linux
# CI legs (and any local `./setup.ps1 dry-run` run, on any platform) for
# every single push since this check was added - confirmed via the GitHub
# Actions API: "Dry-run setup engine" has failed on every main-branch run
# since 2026-09-12, unnoticed because "Validate repository" (the OTHER step,
# invoked directly, not through this bare-& pattern) passed every time and
# looked like proof CI was healthy.
& pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\ci\validate.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$Platform = if ($env:OS -eq "Windows_NT") {
    "Windows"
} elseif ($IsMacOS) {
    "macOS"
} elseif ($IsLinux) {
    "Linux"
} else {
    $PSVersionTable.OS
}

Write-Host "DRY RUN"
Write-Host "OS:   $Platform"
Write-Host "Repo: $Root"
Write-Host "Would install platform packages, fonts, shell configuration, editor config,"
Write-Host "git hooks, global workstation command and autosync service."
