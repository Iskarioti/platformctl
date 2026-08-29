param([switch]$Once)

$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$LockDir = Join-Path $Root ".state\autosync.lock"
New-Item -ItemType Directory -Force -Path (Join-Path $Root ".state") | Out-Null

try {
    New-Item -ItemType Directory -Path $LockDir -ErrorAction Stop | Out-Null
} catch {
    exit 0
}

try {
    Set-Location $Root
    $Dirty = git status --porcelain
    if (-not $Dirty) { exit 0 }

    & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") validate
    & pwsh -NoLogo -NoProfile -File (Join-Path $Root "setup.ps1") apply --quiet

    git add -u

    $Safe = @(
        ".github",".githooks","config","docs","platform","policy","schema","scripts","shell",
        "templates","vscode","windows","windows-terminal","wsl",
        "AGENTS.md","CLAUDE.md","KIMI.md","README.md","CHANGELOG.md","VERSION",
        "bootstrap","bootstrap.ps1","setup","setup.ps1","workstation.json"
    )
    foreach ($Item in $Safe) {
        if (Test-Path (Join-Path $Root $Item)) {
            git add -- $Item
        }
    }

    $Names = git diff --cached --name-only
    foreach ($Name in $Names) {
        if ($Name -match '(^|/)\.env\.example$') {
            continue
        }

        if ($Name -match '(^|/)(\.env(\..*)?|id_rsa|id_ed25519|secrets?|credentials?)(/|$)|\.(pem|key|pfx|p12|kdbx)$') {
            git reset
            throw "Autosync refused: staged file looks secret-bearing: $Name"
        }
    }

    git diff --cached --quiet
    if ($LASTEXITCODE -eq 0) { exit 0 }

    $HostName = hostname.exe
    $Stamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    $env:WORKSTATION_AUTOSYNC = "1"
    git commit -m "chore(workstation): autosync $HostName $Stamp"

    $Branch = git branch --show-current
    if (-not $Branch) { exit 0 }

    git pull --rebase --autostash origin $Branch
    if ($LASTEXITCODE -ne 0) {
        throw "Autosync committed locally but remote rebase needs manual resolution."
    }

    git push -u origin $Branch
} finally {
    Remove-Item $LockDir -Recurse -Force -ErrorAction SilentlyContinue
}
