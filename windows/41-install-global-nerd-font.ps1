# Compatibility wrapper. v3 standardizes on JetBrains Mono fonts.
& (Join-Path $PSScriptRoot "41-install-fonts.ps1") @args
exit $LASTEXITCODE
