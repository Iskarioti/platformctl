$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
git -C $Root config core.hooksPath .githooks
git -C $Root config pull.rebase true
git -C $Root config fetch.prune true
Write-Host "Git hooks installed. Commits validate; normal commits auto-apply and auto-push current branch."
