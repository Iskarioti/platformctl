#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$packages = @(
    @{ Name = "PowerShell 7";       Id = "Microsoft.PowerShell" },
    @{ Name = "Windows Terminal";   Id = "Microsoft.WindowsTerminal" },
    @{ Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" },
    @{ Name = "PowerToys";          Id = "Microsoft.PowerToys" },
    @{ Name = "Git";                Id = "Git.Git" },
    @{ Name = "Azure CLI";          Id = "Microsoft.AzureCLI" },
    @{ Name = "7-Zip";              Id = "7zip.7zip" },
    @{ Name = "Wireshark";          Id = "WiresharkFoundation.Wireshark" }
)

$failed = @()

foreach ($pkg in $packages) {
    Write-Host ""
    Write-Host "=== $($pkg.Name) [$($pkg.Id)] ===" -ForegroundColor Cyan

    winget list --id $pkg.Id --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Already installed. Checking for upgrade..."
        winget upgrade --id $pkg.Id --exact --source winget --silent `
            --accept-package-agreements --accept-source-agreements

        winget list --id $pkg.Id --exact --source winget 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            $failed += $pkg
            Write-Warning "Verification failed for $($pkg.Id)"
        }
        continue
    }

    Write-Host "Installing..."
    winget install --id $pkg.Id --exact --source winget --silent `
        --accept-package-agreements --accept-source-agreements

    if ($LASTEXITCODE -ne 0) {
        $failed += $pkg
        Write-Warning "Installation failed for $($pkg.Id)"
        continue
    }

    winget list --id $pkg.Id --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $failed += $pkg
        Write-Warning "Post-install verification failed for $($pkg.Id)"
    }
}

# Sysinternals: use the Microsoft Store package while the stable WinGet ZIP
# manifest can become temporarily stale when Microsoft replaces the archive.
Write-Host ""
Write-Host "=== Sysinternals Suite ===" -ForegroundColor Cyan
$SysinternalsStoreId = "9P7KNL5RWT25"
winget list --id $SysinternalsStoreId --source msstore 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sysinternals Suite already installed."
} else {
    winget install --id $SysinternalsStoreId --source msstore `
        --accept-package-agreements --accept-source-agreements
    if ($LASTEXITCODE -ne 0) {
        $failed += @{ Name = "Sysinternals Suite"; Id = $SysinternalsStoreId }
        Write-Warning "Sysinternals Store installation failed. Do not bypass installer hash validation."
    }
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Warning "One or more baseline packages failed:"
    $failed | ForEach-Object { Write-Warning " - $($_.Name) [$($_.Id)]" }
    throw "Baseline Windows tool installation did not complete successfully."
}

Write-Host "All baseline Windows tools are installed and verified." -ForegroundColor Green
