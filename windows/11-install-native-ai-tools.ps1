# Claude Code, Codex CLI, and the Claude desktop app, installed via each
# vendor's own NATIVE installer instead of winget - requested 2026-10-21 "to
# get the best out of the applications." Confirmed via each vendor's own
# official docs (code.claude.com/docs/en/setup, read directly; Codex's
# install.ps1 read directly after chatgpt.com/codex/install.ps1 - confirmed
# via curl -I that it 302-redirects to releases.openai.com, a real OpenAI
# domain, not a spoofed one) this is a real, meaningful difference, not just
# a preference:
#
#   - Claude Code's own docs state outright: "Native installations
#     automatically update in the background... WinGet installations do not
#     auto-update by default... On WinGet the upgrade may fail while Claude
#     Code is running because Windows locks the executable" - this is
#     EXACTLY the friction windows/10-install-tools.ps1's ProcessName skip
#     was built to work around (see that file). The native installer
#     sidesteps the problem at the root instead of working around it.
#   - Codex CLI's own install.ps1 (read directly, not guessed) has its own
#     auto-update-version tracking and a background "daemon" reference,
#     indicating the same kind of self-managed update story.
#   - The Claude desktop app is the one exception: its official direct
#     download (claude.ai/api/desktop/.../redirect) sits behind a
#     Cloudflare "managed" bot challenge that isn't scriptable (confirmed
#     live - a plain download attempt gets a JS challenge page, not the
#     installer, even with a realistic browser User-Agent). Installed via
#     its Microsoft Store listing instead (Anthropic's own first-party
#     packaging, id 9P6K58THS811) - confirmed with Andrew given the direct
#     download genuinely can't be automated. Still a different source than
#     the community winget catalog this migration moves away from, and it
#     auto-updates through Windows' own Store mechanism.
#
# This script is deliberately NOT run with admin elevation (unlike
# 10-install-tools.ps1) - Claude Code/Codex CLI's native installers install
# per-user under %USERPROFILE%/%LOCALAPPDATA% (same pattern as pixi/
# Quarto's non-winget installs on the POSIX side), and a Microsoft Store
# app install doesn't need it either.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "=== Claude Code, Codex CLI, Claude desktop (native installers) ===" -ForegroundColor Cyan

# Refresh PATH the same way 43-configure-taskbar-appearance.ps1 already does -
# a package just installed earlier in this same session (by 10-install-tools.ps1,
# run moments before this script in bootstrap.ps1's sequence) only updates the
# on-disk PATH, not this already-loaded process's copy.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("Path", "User")

function Uninstall-WingetPackageIfPresent {
    param(
        [Parameter(Mandatory)][string]$Id,
        [Parameter(Mandatory)][string]$Name
    )
    winget list --id $Id --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Removing winget-managed $Name ($Id) before installing the native version..."
        winget uninstall --id $Id --exact --source winget --silent | Out-Null
    }
}

# Confirmed live, 2026-10-21: `powershell.exe -Command "irm <url> | iex"`
# fails on this machine with "Cannot convert value to type ... Only core
# types are supported in this language mode" - the same ConstrainedLanguage
# Mode restriction this repo has hit repeatedly for other inline (-Command)
# PowerShell invocations elsewhere (ad-hoc commands run restricted; a
# trusted script file run via -File does not). Downloading the installer to
# a file first and running it via -File sidesteps this exactly like every
# other script-invocation in this repo already does.
function Invoke-RemoteInstallScript {
    param([Parameter(Mandatory)][string]$Url)
    $ScriptPath = Join-Path $env:TEMP ("install-" + [Guid]::NewGuid().ToString("N") + ".ps1")
    try {
        Invoke-WebRequest -Uri $Url -OutFile $ScriptPath -UseBasicParsing
        & pwsh.exe -NoLogo -NoProfile -File $ScriptPath
    } finally {
        Remove-Item -LiteralPath $ScriptPath -Force -ErrorAction SilentlyContinue
    }
}

# Confirmed live, 2026-10-21: the Claude DESKTOP app's Electron processes
# (main + several renderer/GPU/utility processes) ALL share the plain image
# name "claude.exe" - Get-Process -Name "claude" matched NINE separate
# processes at once with the desktop app simply open, every one of them
# under Program Files\WindowsApps\Claude_<version>\..., plus one genuinely
# separate process from the WinGet-installed Claude Code CLI shim
# (AppData\Local\Microsoft\WinGet\Links\claude.exe). A bare name match can't
# tell these apart, so a name-only guard for either tool would wrongly skip
# every time the OTHER one happens to be open. Filtering by the actual
# executable path distinguishes them correctly - verified directly against
# this machine's real process list.
function Test-ProcessRunningAtAnyPath {
    param([Parameter(Mandatory)][string]$Name, [Parameter(Mandatory)][string[]]$PathContains)
    $procs = Get-Process -Name $Name -ErrorAction SilentlyContinue
    foreach ($proc in $procs) {
        if (-not $proc.Path) { continue }
        foreach ($fragment in $PathContains) {
            if ($proc.Path -like "*$fragment*") { return $true }
        }
    }
    return $false
}

# --- Claude Code ---
#
# Confirmed live, repeatedly, elsewhere in this repo's history (see
# 10-install-tools.ps1's own ProcessName comment): Claude Code is very often
# the process actually RUNNING this script, since a workstation
# bootstrap/upgrade is very often run from inside a Claude Code session.
# Migrating off winget means uninstalling the currently-installed winget
# package first - doing that to your own running executable is exactly the
# "remove: Access is denied" failure mode this whole migration is meant to
# get away from. Skip entirely while it's running; re-run this script (or
# just `workstation apply`/bootstrap again) from a closed session to
# actually migrate.
if (Test-ProcessRunningAtAnyPath -Name "claude" -PathContains @("WinGet\Links", ".local\bin")) {
    Write-Host "Skipping Claude Code migration - the claude CLI is currently running (this may BE the" -ForegroundColor Yellow
    Write-Host "running session). Re-run this from a closed Claude Code session to migrate." -ForegroundColor Yellow
} else {
    $ClaudeNativePath = Join-Path $env:USERPROFILE ".local\bin\claude.exe"
    if (Test-Path -LiteralPath $ClaudeNativePath -PathType Leaf) {
        Write-Host "Claude Code already natively installed."
    } else {
        Uninstall-WingetPackageIfPresent -Id "Anthropic.ClaudeCode" -Name "Claude Code"
        Write-Host "Installing Claude Code (native installer)..."
        Invoke-RemoteInstallScript -Url "https://claude.ai/install.ps1"
        if (-not (Test-Path -LiteralPath $ClaudeNativePath -PathType Leaf)) {
            Write-Warning "Claude Code native install did not produce $ClaudeNativePath - verify manually (claude --version)."
        } else {
            Write-Host "Claude Code installed natively - it updates itself automatically from here." -ForegroundColor Green
        }
    }
}

# --- Codex CLI ---
#
# Same self-lock risk in principle as Claude Code, far less likely in
# practice (this repo's own agent-session work overwhelmingly runs under
# Claude Code, not Codex) - guarded identically anyway, cheap insurance.
if (Get-Process -Name "codex" -ErrorAction SilentlyContinue) {
    Write-Host "Skipping Codex CLI migration - codex is currently running." -ForegroundColor Yellow
} else {
    $CodexNativePath = Join-Path $env:LOCALAPPDATA "Programs\OpenAI\Codex\bin\codex.exe"
    if (Test-Path -LiteralPath $CodexNativePath -PathType Leaf) {
        Write-Host "Codex CLI already natively installed."
    } else {
        Uninstall-WingetPackageIfPresent -Id "OpenAI.Codex" -Name "Codex CLI"
        Write-Host "Installing Codex CLI (native installer)..."
        Invoke-RemoteInstallScript -Url "https://chatgpt.com/codex/install.ps1"
        if (-not (Test-Path -LiteralPath $CodexNativePath -PathType Leaf)) {
            Write-Warning "Codex CLI native install did not produce $CodexNativePath - verify manually (codex --version)."
        } else {
            Write-Host "Codex CLI installed natively." -ForegroundColor Green
        }
    }
}

# --- Claude desktop app ---
#
# Anthropic's own direct-download endpoint (claude.ai/api/desktop/.../
# redirect, linked from claude.com/download) sits behind a Cloudflare
# "managed" bot challenge - confirmed live, directly: a plain
# Invoke-WebRequest gets a JS challenge page, not the installer, even with a
# realistic browser User-Agent header. That's not scriptable without a real
# browser engine, so this uses Claude's official Microsoft Store listing
# instead (id 9P6K58THS811, confirmed via `winget search Claude --source
# msstore`) - Anthropic's own first-party Store packaging, not the
# community winget catalog the rest of this migration moves away from, and
# it self-updates via Windows' own Store update mechanism rather than
# needing Claude's own updater at all. Same `--source msstore` pattern this
# repo already uses for Sysinternals Suite in 10-install-tools.ps1 - a
# deliberate choice, confirmed with Andrew given the direct download isn't
# automatable at all.
if (Test-ProcessRunningAtAnyPath -Name "claude" -PathContains @("WindowsApps\Claude_")) {
    Write-Host "Skipping Claude desktop install/update - the desktop app is currently running." -ForegroundColor Yellow
} else {
    winget list --id "Anthropic.Claude" --exact --source winget 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Removing community-winget-managed Claude desktop app before installing the Microsoft Store version..."
        winget uninstall --id "Anthropic.Claude" --exact --source winget --silent | Out-Null
    }

    winget list --id "9P6K58THS811" --exact --source msstore 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Claude desktop app already installed via Microsoft Store."
    } else {
        Write-Host "Installing Claude desktop app from the Microsoft Store..."
        winget install --id "9P6K58THS811" --exact --source msstore --silent `
            --accept-package-agreements --accept-source-agreements
        Write-Host "Claude desktop app installed via Microsoft Store - it updates itself through Windows." -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "Native AI tool installation complete." -ForegroundColor Green
