param(
    [switch]$NoAutoSync,
    [switch]$NoAutoUpgrade,
    [switch]$NoWSL
)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")

function Run {
    param(
        [Parameter(Mandatory)]
        [string]$Relative,

        [string[]]$Arguments = @()
    )

    $Path = Join-Path $Root $Relative

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required bootstrap component not found: $Path"
    }

    Write-Host ""
    Write-Host "=== $Relative ===" -ForegroundColor Cyan

    pwsh.exe `
        -NoLogo `
        -NoProfile `
        -File $Path `
        @Arguments

    if ($LASTEXITCODE -ne 0) {
        throw "$Relative failed with exit code $LASTEXITCODE"
    }
}

Get-ChildItem $Root -Recurse -File -ErrorAction SilentlyContinue |
    Unblock-File -ErrorAction SilentlyContinue

Run "windows\10-install-tools.ps1"
Run "windows\11-install-native-ai-tools.ps1"
Run "windows\41-install-fonts.ps1"
Run "windows\42-configure-windows-terminal.ps1"
Run "windows\43-configure-taskbar-appearance.ps1"
Run "windows\45-shell-experience.ps1"

if (-not $NoWSL) {
    Run "windows\20-install-wsl.ps1"
    # 25-set-wsl-profile.ps1's -Profile param is mandatory - calling it with no
    # arguments (as this line did until now) hits an interactive "cannot be
    # null" prompt for a value, silently turning what looks like an
    # unattended bootstrap into one that hangs waiting for console input the
    # user has no reason to expect. "default" is the base profile every other
    # real caller in this repo passes (see docs/getting-started.md) -
    # "ai-lab" is an opt-in the user runs by hand afterward
    # when they actually need it (ai-runtime/README.md), not a bootstrap default.
    Run "windows\25-set-wsl-profile.ps1" -Arguments @("-Profile", "default")
}

Run "scripts\windows\configure-vscode.ps1"
Run "scripts\common\install-git-hooks.ps1"
Run "scripts\windows\install-workstation-command.ps1"

# Re-apply because the command installer may update the canonical PowerShell profile.
Run "scripts\windows\apply.ps1"

if (-not $NoAutoSync) {
    Run "scripts\windows\install-autosync.ps1"
}

if (-not $NoAutoUpgrade) {
    Run "scripts\windows\install-autoupgrade.ps1"
}

Run "scripts\common\doctor.ps1"

Write-Host "`nWindows workstation bootstrap completed." -ForegroundColor Green
Write-Host "Close Windows Terminal completely and open a new PowerShell 7 session."

if (-not $NoWSL) {
    # docs/new-machine.md describes wsl/bootstrap.sh's SSH-key/git-identity/
    # DevSecOps-toolchain setup right next to this script's own output, which
    # reads as if it already ran as part of this bootstrap - it doesn't.
    # Nothing in this script (or anywhere else) invokes it automatically:
    # confirmed live, nothing greps to a real call site outside wsl/ itself.
    # Deliberately NOT auto-chained here either - wsl/bootstrap.sh runs
    # `sudo apt update && apt full-upgrade`, which needs an interactive sudo
    # password every time (this repo has hit that exact "sudo hangs
    # non-interactively" wall before), and a first-ever launch of a distro
    # can itself block on an interactive username/password prompt - not
    # something to fire unattended from here. Printing this instead of
    # silently leaving it to a separate doc page, so it's not missed.
    Write-Host ""
    Write-Host "=== Next: WSL engineering control plane ===" -ForegroundColor Cyan
    Write-Host "This Windows-side bootstrap does NOT set up WSL's own toolchain (SSH"
    Write-Host "key, git identity, DevSecOps/research tools) - that needs one more,"
    Write-Host "interactive step (it will prompt for your WSL sudo password, and for a"
    Write-Host "WSL username/password too if this is Ubuntu's very first launch):"
    # The printed `cd` target must be the WSL-side mount path (e.g. /mnt/c/...),
    # not $Root's Windows path - this instruction is meant to be typed INSIDE
    # the WSL shell the "wsl" line above just opened. Resolved via `wslpath`
    # itself rather than hardcoding /mnt/c, so a machine with a customized
    # mount point still gets a correct answer.
    $WslRepoPath = (& wsl.exe wslpath -u "$Root" 2>$null | Select-Object -First 1)
    if (-not $WslRepoPath) { $WslRepoPath = "<this repo's path, from inside WSL>" }
    Write-Host ""
    Write-Host "    wsl" -ForegroundColor Yellow
    Write-Host "    cd `"$WslRepoPath`"" -ForegroundColor Yellow
    Write-Host "    ./wsl/bootstrap.sh" -ForegroundColor Yellow
    Write-Host ""
}

# Informational: report development-policy compliance without failing bootstrap
# over it (enforce.ps1 legitimately reports non-zero when policy is unmet, e.g.
# after -NoWSL).
& pwsh.exe -NoLogo -NoProfile -File (Join-Path $Root "scripts\common\enforce.ps1")
