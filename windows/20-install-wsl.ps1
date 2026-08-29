#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"

$TargetDistro = "Ubuntu-24.04"

Write-Host "=== WSL ===" -ForegroundColor Cyan

# ------------------------------------------------------------
# 1. Verify WSL is available
# ------------------------------------------------------------

if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
    throw "wsl.exe is not available on this system."
}

# ------------------------------------------------------------
# 2. Attempt WSL update
#
# Update failure is non-fatal on managed/corporate endpoints.
# The existing WSL installation may still be fully operational.
# ------------------------------------------------------------

Write-Host "Checking for WSL updates..."

wsl.exe --update

if ($LASTEXITCODE -ne 0) {
    Write-Warning "WSL update could not be completed."
    Write-Warning "This may be caused by corporate proxy, firewall, Store, or endpoint policy."
    Write-Warning "Continuing with the installed WSL version."
}
else {
    Write-Host "WSL update check completed."
}

# ------------------------------------------------------------
# 3. Ensure WSL2 is the default for future distributions
# ------------------------------------------------------------

Write-Host "Ensuring WSL2 is the default version..."

wsl.exe --set-default-version 2

if ($LASTEXITCODE -ne 0) {
    throw "Failed to configure WSL2 as the default version."
}

# ------------------------------------------------------------
# 4. Discover installed distributions robustly
#
# wsl.exe output can contain NULL characters depending on the
# Windows/PowerShell/native-output combination. Strip them.
# ------------------------------------------------------------

$InstalledDistros = @()

$RawDistros = wsl.exe --list --quiet 2>$null

foreach ($RawDistro in $RawDistros) {

    $Distro = ($RawDistro -replace "`0", "").Trim()

    if ($Distro) {
        $InstalledDistros += $Distro
    }
}

Write-Host ""
Write-Host "Installed WSL distributions:"

if ($InstalledDistros.Count -eq 0) {
    Write-Host "  None"
}
else {
    foreach ($Distro in $InstalledDistros) {
        Write-Host "  - $Distro"
    }
}

# ------------------------------------------------------------
# 5. Determine whether Ubuntu already exists
# ------------------------------------------------------------

$UbuntuInstalled = $false

foreach ($Distro in $InstalledDistros) {

    if ($Distro -eq $TargetDistro) {
        $UbuntuInstalled = $true
        break
    }
}

# ------------------------------------------------------------
# 6. Install only when genuinely absent
# ------------------------------------------------------------

if ($UbuntuInstalled) {

    Write-Host ""
    Write-Host "$TargetDistro is already installed." -ForegroundColor Green

}
else {

    Write-Host ""
    Write-Host "Installing $TargetDistro..."

    wsl.exe --install -d $TargetDistro

    if ($LASTEXITCODE -ne 0) {
        throw "Installation of $TargetDistro failed."
    }

    Write-Host ""
    Write-Host "$TargetDistro installation requested."
    Write-Host "Restart Windows only if Windows requests it."
    Write-Host "Then launch $TargetDistro once to complete first-run initialization."
}

# ------------------------------------------------------------
# 7. Show final WSL state
# ------------------------------------------------------------

Write-Host ""
Write-Host "=== WSL Status ==="

wsl.exe --list --verbose

if ($LASTEXITCODE -ne 0) {
    throw "Unable to retrieve WSL distribution status."
}

Write-Host ""
Write-Host "WSL configuration complete." -ForegroundColor Green
