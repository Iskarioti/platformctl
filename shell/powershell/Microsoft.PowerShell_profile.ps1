#Requires -Version 7.0
# ============================================================================
# Systems & Platform Architect - PowerShell 7
# Terminal-first engineering profile.
#
# Design goals:
# - safe on enterprise-managed endpoints using ConstrainedLanguage/App Control;
# - fast startup and predictable behavior;
# - PowerShell as the single Windows Terminal entry point;
# - WSL as the Linux/Docker engineering plane;
# - Oh My Posh + Tokyo Night for the prompt;
# - no weakening of execution policy, App Control, WDAC or CLM.
# ============================================================================

$env:VIRTUAL_ENV_DISABLE_PROMPT = "1"
$env:POSH_THEME = "$HOME\.config\oh-my-posh\tokyonight-architect.omp.json"

# Keep common CLI output deterministic.
$env:CLICOLOR = "1"
$env:TERM_PROGRAM = "Windows_Terminal"

# ----------------------------------------------------------------------------
# PSReadLine
# ----------------------------------------------------------------------------

if (Get-Module -ListAvailable -Name PSReadLine) {
    Import-Module PSReadLine -ErrorAction SilentlyContinue

    Set-PSReadLineOption -EditMode Windows -ErrorAction SilentlyContinue
    Set-PSReadLineOption -BellStyle None -ErrorAction SilentlyContinue
    Set-PSReadLineOption -HistorySaveStyle SaveIncrementally -ErrorAction SilentlyContinue
    Set-PSReadLineOption -HistorySearchCursorMovesToEnd -ErrorAction SilentlyContinue
    Set-PSReadLineOption -MaximumHistoryCount 100000 -ErrorAction SilentlyContinue
    Set-PSReadLineOption -HistoryNoDuplicates -ErrorAction SilentlyContinue

    try {
        Set-PSReadLineOption -PredictionSource History
        Set-PSReadLineOption -PredictionViewStyle ListView
    } catch {}

    # Navigation / completion.
    Set-PSReadLineKeyHandler -Chord UpArrow -Function HistorySearchBackward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord DownArrow -Function HistorySearchForward -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Tab -Function MenuComplete -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+Spacebar -Function MenuComplete -ErrorAction SilentlyContinue

    # Fast history search.
    Set-PSReadLineKeyHandler -Chord Ctrl+r -Function ReverseSearchHistory -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+s -Function ForwardSearchHistory -ErrorAction SilentlyContinue

    # Line editing.
    Set-PSReadLineKeyHandler -Chord Ctrl+a -Function BeginningOfLine -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+e -Function EndOfLine -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+LeftArrow -Function BackwardWord -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+RightArrow -Function ForwardWord -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Alt+Backspace -Function BackwardKillWord -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+z -Function Undo -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+y -Function Redo -ErrorAction SilentlyContinue
    Set-PSReadLineKeyHandler -Chord Ctrl+l -Function ClearScreen -ErrorAction SilentlyContinue
}

# ----------------------------------------------------------------------------
# Basic shell quality-of-life
# ----------------------------------------------------------------------------

function ..   { Set-Location .. }
function ...  { Set-Location ../.. }
function .... { Set-Location ../../.. }

function ll {
    Get-ChildItem @args
}

function la {
    Get-ChildItem -Force @args
}

function touch {
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path) {
        (Get-Item -LiteralPath $Path).LastWriteTime = Get-Date
    } else {
        New-Item -ItemType File -Path $Path | Out-Null
    }
}

function mkcd {
    param([Parameter(Mandatory)][string]$Path)
    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    Set-Location -LiteralPath $Path
}

function which {
    param([Parameter(Mandatory)][string]$Name)
    Get-Command $Name -All
}

function paths {
    $env:PATH -split ";" | Where-Object { $_ }
}

function tailf {
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Tail = 100
    )
    Get-Content -LiteralPath $Path -Tail $Tail -Wait
}

function croot {
    $Root = git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $Root) {
        Set-Location -LiteralPath $Root
    }
}

# ----------------------------------------------------------------------------
# Git
# ----------------------------------------------------------------------------

function gs   { git status @args }
function ga   { git add @args }
function gaa  { git add --all }
function gc   { git commit @args }
function gca  { git commit --amend @args }
function gp   { git push @args }
function gl   { git pull --ff-only @args }
function gf   { git fetch --all --prune @args }
function gd   { git diff @args }
function gds  { git diff --staged @args }
function gb   { git branch @args }
function gsw  { git switch @args }
function glog { git log --graph --decorate --oneline --all @args }

function gbranch {
    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        git branch
        return
    }

    $Branch = git branch --format="%(refname:short)" | fzf --height 40% --reverse --prompt "git branch> "
    if ($Branch) {
        git switch $Branch
    }
}

# ----------------------------------------------------------------------------
# WSL / Linux engineering plane
# ----------------------------------------------------------------------------

function w {
    wsl.exe @args
}

function wu {
    wsl.exe -d Ubuntu-24.04 -- @args
}

function linux {
    wsl.exe -d Ubuntu-24.04
}

function ops {
    wsl.exe -d Ubuntu-24.04 -- bash -lc "tmux new-session -A -s ops"
}

function wstatus {
    wsl.exe --list --verbose
}

function wstop {
    wsl.exe --shutdown
}

function wpath {
    param([Parameter(Mandatory)][string]$Path)
    wsl.exe -d Ubuntu-24.04 -- wslpath -a $Path
}

# ----------------------------------------------------------------------------
# Docker - the single Docker Engine lives in WSL
# ----------------------------------------------------------------------------

function docker {
    wsl.exe -d Ubuntu-24.04 -- docker @args
}

function d {
    wsl.exe -d Ubuntu-24.04 -- docker @args
}

function dc {
    wsl.exe -d Ubuntu-24.04 -- docker compose @args
}

function dps {
    wsl.exe -d Ubuntu-24.04 -- docker ps
}

function dpa {
    wsl.exe -d Ubuntu-24.04 -- docker ps -a
}

function ddf {
    wsl.exe -d Ubuntu-24.04 -- docker system df
}

function dlogs {
    param(
        [Parameter(Mandatory)][string]$Container,
        [int]$Tail = 200
    )
    wsl.exe -d Ubuntu-24.04 -- docker logs --tail $Tail -f $Container
}

function dex {
    param(
        [Parameter(Mandatory)][string]$Container,
        [string]$Shell = "sh"
    )
    wsl.exe -d Ubuntu-24.04 -- docker exec -it $Container $Shell
}

# ----------------------------------------------------------------------------
# Project navigation / VS Code through WSL
# ----------------------------------------------------------------------------

function dev {
    param([Parameter(Mandatory)][string]$Repo)
    wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/src/company/$Repo && code ."
}

function platform {
    param([Parameter(Mandatory)][string]$Repo)
    wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/src/platform/$Repo && code ."
}

function lab {
    param([Parameter(Mandatory)][string]$Repo)
    wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/src/labs/$Repo && code ."
}

function tooling {
    param([string]$Repo = "")
    if ($Repo) {
        wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/src/tooling/$Repo && code ."
    } else {
        wsl.exe -d Ubuntu-24.04 -- bash -lc "cd ~/src/tooling && code ."
    }
}

function fcd {
    param([string]$Root = $HOME)

    if (-not (Get-Command fzf -ErrorAction SilentlyContinue)) {
        Write-Warning "fzf is not installed."
        return
    }

    $Target = Get-ChildItem -LiteralPath $Root -Directory -Recurse -Depth 3 -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName |
        fzf --height 50% --reverse --prompt "cd> "

    if ($Target) {
        Set-Location -LiteralPath $Target
        if (Get-Command zoxide -ErrorAction SilentlyContinue) {
            zoxide add -- $Target | Out-Null
        }
    }
}

# ----------------------------------------------------------------------------
# Azure
# ----------------------------------------------------------------------------

function azctx {
    az account show --query "{subscription:name,user:user.name,tenant:tenantId}" --output table
}

function azsubs {
    az account list --query "[].{Name:name,Subscription:id,State:state,Default:isDefault}" --output table
}

function azuse {
    param([Parameter(Mandatory)][string]$Subscription)
    az account set --subscription $Subscription
    if ($LASTEXITCODE -eq 0) {
        azctx
    }
}

function azgroups {
    az group list --query "[].{Name:name,Location:location}" --output table
}

# ----------------------------------------------------------------------------
# Kubernetes / Terraform helpers
# ----------------------------------------------------------------------------

function k    { kubectl @args }
function kgp  { kubectl get pods @args }
function kga  { kubectl get all @args }
function kctx { kubectl config current-context }
function kns  {
    param([Parameter(Mandatory)][string]$Namespace)
    kubectl config set-context --current --namespace=$Namespace
}

function tf    { terraform @args }
function tfi   { terraform init @args }
function tfp   { terraform plan @args }
function tfa   { terraform apply @args }
function tffmt { terraform fmt -recursive @args }
function tfv   { terraform validate @args }

# ----------------------------------------------------------------------------
# Network / platform diagnostics
# ----------------------------------------------------------------------------

function myip {
    Get-NetIPConfiguration |
        Where-Object IPv4Address |
        Select-Object InterfaceAlias, IPv4Address, IPv4DefaultGateway, DNSServer
}

function listen {
    Get-NetTCPConnection -State Listen |
        Sort-Object LocalPort |
        Select-Object LocalAddress, LocalPort, OwningProcess
}

function tcp {
    param(
        [Parameter(Mandatory)][string]$HostName,
        [Parameter(Mandatory)][int]$Port
    )
    Test-NetConnection -ComputerName $HostName -Port $Port -InformationLevel Detailed
}

function trace {
    param([Parameter(Mandatory)][string]$HostName)
    Test-NetConnection -ComputerName $HostName -TraceRoute
}

function dns {
    param(
        [Parameter(Mandatory)][string]$Name,
        [string]$Type = "A"
    )
    Resolve-DnsName -Name $Name -Type $Type
}

function routes {
    Get-NetRoute |
        Sort-Object InterfaceIndex, DestinationPrefix |
        Select-Object InterfaceIndex, DestinationPrefix, NextHop, RouteMetric, State
}

function proc {
    param([Parameter(Mandatory)][int]$Id)
    Get-Process -Id $Id
}

function toolversions {
    Write-Host "PowerShell: $($PSVersionTable.PSVersion)"
    if (Get-Command git -ErrorAction SilentlyContinue)         { git --version }
    if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) { oh-my-posh version }
    if (Get-Command az -ErrorAction SilentlyContinue)          { az version --query '"azure-cli"' -o tsv }
    if (Get-Command gh -ErrorAction SilentlyContinue)          { gh --version | Select-Object -First 1 }
    if (Get-Command kubectl -ErrorAction SilentlyContinue)     { kubectl version --client }
    if (Get-Command terraform -ErrorAction SilentlyContinue)   { terraform version }
    wsl.exe --status
}

# ----------------------------------------------------------------------------
# zoxide
# ----------------------------------------------------------------------------

if (Get-Command zoxide -ErrorAction SilentlyContinue) {

    # Seed useful locations so a new database is immediately usable.
    foreach ($Seed in @($HOME, "$HOME\Documents", "$HOME\Downloads")) {
        if (Test-Path -LiteralPath $Seed) {
            zoxide add -- $Seed | Out-Null
        }
    }

    if ($ExecutionContext.SessionState.LanguageMode -eq "ConstrainedLanguage") {

        # Avoid dynamically evaluating zoxide's generated PowerShell initializer
        # under CLM. These wrappers provide the useful behavior directly.
        function z {
            if ($args.Count -eq 0) {
                Set-Location -LiteralPath $HOME
                zoxide add -- $HOME | Out-Null
                return
            }

            if (($args.Count -eq 1) -and (Test-Path -LiteralPath $args[0] -PathType Container)) {
                Set-Location -LiteralPath $args[0]
                zoxide add -- "$PWD" | Out-Null
                return
            }

            $Target = zoxide query -- @args
            if ($LASTEXITCODE -eq 0 -and $Target) {
                Set-Location -LiteralPath $Target
                zoxide add -- $Target | Out-Null
            }
        }

        function zi {
            $Target = zoxide query -i -- @args
            if ($LASTEXITCODE -eq 0 -and $Target) {
                Set-Location -LiteralPath $Target
                zoxide add -- $Target | Out-Null
            }
        }

    } else {
        try {
            zoxide init powershell | Invoke-Expression -ErrorAction Stop
        } catch {
            Write-Warning "zoxide initialization failed; use the zoxide executable directly."
        }
    }
}

# ----------------------------------------------------------------------------
# Oh My Posh - keep this last
# ----------------------------------------------------------------------------

if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {

    if ($ExecutionContext.SessionState.LanguageMode -eq "ConstrainedLanguage") {
        # Oh My Posh documents POSH_CONSTRAINED_LANGUAGE for managed sessions.
        # Use native chcp instead of restricted static .NET encoding methods.
        chcp.com 65001 > $null 2>&1
        $env:POSH_CONSTRAINED_LANGUAGE = "1"

        # Prefer the classic prompt path on locked-down endpoints. This avoids
        # background streaming complexity while preserving the Oh My Posh theme.
        $env:POSH_DISABLE_STREAMING = "1"
    }

    try {
        $PoshInit = oh-my-posh init pwsh --config $env:POSH_THEME --strict
        if ($LASTEXITCODE -eq 0 -and $PoshInit) {
            $PoshInit | Invoke-Expression -ErrorAction Stop
        }
    } catch {
        Write-Warning "Oh My Posh initialization failed; using a minimal CLM-safe prompt."

        function global:prompt {
            $Leaf = Split-Path -Leaf (Get-Location)
            if (-not $Leaf) { $Leaf = "~" }

            if ($?) {
                "󰍲 $Leaf ❯ "
            } else {
                "󰍲 $Leaf ✘ "
            }
        }
    }
}

function workstation {
    $RepoPathFile = Join-Path $HOME ".config\workstation\repo-path"
    if (-not (Test-Path $RepoPathFile)) {
        Write-Error "Workstation repo path is not registered."
        return
    }
    $Repo = (Get-Content $RepoPathFile -Raw).Trim()
    & pwsh.exe -NoLogo -NoProfile -File (Join-Path $Repo "setup.ps1") @args
}
