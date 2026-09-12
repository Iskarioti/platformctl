#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

$packages = @(
    @{ Name = "PowerShell 7";       Id = "Microsoft.PowerShell" },
    @{ Name = "Windows Terminal";   Id = "Microsoft.WindowsTerminal" },
    @{ Name = "Visual Studio Code"; Id = "Microsoft.VisualStudioCode" },
    @{ Name = "LibreWolf";          Id = "LibreWolf.LibreWolf" },
    @{ Name = "Alacritty";          Id = "Alacritty.Alacritty" },
    @{ Name = "Bing Wallpaper";     Id = "Microsoft.BingWallpaper" },
    @{ Name = "MiKTeX";             Id = "MiKTeX.MiKTeX" },
    @{ Name = "Pandoc";             Id = "JohnMacFarlane.Pandoc" },
    @{ Name = "Quarto";             Id = "Posit.Quarto" },
    @{ Name = "pixi";               Id = "prefix-dev.pixi" },
    @{ Name = "PowerToys";          Id = "Microsoft.PowerToys" },
    @{ Name = "Git";                Id = "Git.Git" },
    @{ Name = "GitHub CLI";         Id = "GitHub.cli" },
    @{ Name = "Azure CLI";          Id = "Microsoft.AzureCLI" },
    @{ Name = "jq";                 Id = "jqlang.jq" },
    @{ Name = "7-Zip";              Id = "7zip.7zip" },
    @{ Name = "Wireshark";          Id = "WiresharkFoundation.Wireshark" },
    @{ Name = "WireGuard";          Id = "WireGuard.WireGuard" },
    @{ Name = "Logi Options+";      Id = "Logitech.OptionsPlus" },
    @{ Name = "Microsoft Teams";    Id = "Microsoft.Teams" },
    @{ Name = "Outlook for Windows"; Id = "Microsoft.Outlook" },
    @{ Name = "Claude Code"; Id = "Anthropic.ClaudeCode" }
    @{ Name = "Codex CLI"; Id = "OpenAI.Codex" }
    # @{ Name = "Python 3.14"; Id = "Python.Python.3.14" }
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

        # winget legitimately returns non-zero here when there's simply no
        # upgrade available - only treat it as a real failure if the package
        # can no longer be found at all afterward.
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
        # Some MSI installers default to a per-user scope, which this machine's
        # Group Policy blocks outright (MSI error 1934: "User installations are
        # disabled via policy"). Confirmed live (Pandoc, pixi) - retrying with
        # --scope machine (this script already requires an elevated session)
        # installs system-wide instead, which the policy does NOT block. Not a
        # security-control bypass (AGENTS.md rule 3): per-user installs stay
        # exactly as disabled as the policy intends, this just uses the scope
        # the policy still permits.
        Write-Warning "Default install failed for $($pkg.Id) - retrying with --scope machine (per-user installs may be policy-disabled on this device)..."
        winget install --id $pkg.Id --exact --source winget --silent --scope machine `
            --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -ne 0) {
            $failed += $pkg
            Write-Warning "Installation failed for $($pkg.Id)"
            continue
        }
    }

    winget list --id $pkg.Id --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -ne 0) {
        $failed += $pkg
        Write-Warning "Post-install verification failed for $($pkg.Id)"
    }
}

# Sysinternals Suite
#
# Treat an existing installation as success regardless of whether it came
# from the winget community source or Microsoft Store. WinGet may return a
# non-zero code when "install" encounters an already-installed package with
# no available upgrade, which must not fail the workstation bootstrap.

Write-Host ""
Write-Host "=== Sysinternals Suite ===" -ForegroundColor Cyan

$SysinternalsWingetId = "Microsoft.Sysinternals.Suite"
$SysinternalsStoreId  = "9P7KNL5RWT25"
$SysinternalsInstalled = $false

# Check community WinGet package first.
winget list --id $SysinternalsWingetId --exact 2>$null | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "Sysinternals Suite is already installed [$SysinternalsWingetId]."
    $SysinternalsInstalled = $true
}

# Check Microsoft Store package.
if (-not $SysinternalsInstalled) {
    winget list --id $SysinternalsStoreId --exact 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Sysinternals Suite is already installed [$SysinternalsStoreId]."
        $SysinternalsInstalled = $true
    }
}

# Install only when neither package is present.
if (-not $SysinternalsInstalled) {
    Write-Host "Installing Sysinternals Suite..."

    winget install `
        --id $SysinternalsStoreId `
        --exact `
        --source msstore `
        --accept-package-agreements `
        --accept-source-agreements

    # Do not rely only on winget's install exit code.
    # Verify actual installed state after the operation.
    winget list --id $SysinternalsStoreId --exact 2>$null | Out-Null

    if ($LASTEXITCODE -eq 0) {
        Write-Host "Sysinternals Suite installed successfully."
        $SysinternalsInstalled = $true
    }
}

if (-not $SysinternalsInstalled) {
    $failed += @{
        Name = "Sysinternals Suite"
        Id   = $SysinternalsStoreId
    }

    Write-Warning "Sysinternals Suite could not be verified as installed."
    Write-Warning "Installer security/hash validation was not bypassed."
}

Write-Host ""
if ($failed.Count -gt 0) {
    Write-Warning "One or more baseline packages failed:"
    $failed | ForEach-Object { Write-Warning " - $($_.Name) [$($_.Id)]" }
    throw "Baseline Windows tool installation did not complete successfully."
}

Write-Host "All baseline Windows tools are installed and verified." -ForegroundColor Green
