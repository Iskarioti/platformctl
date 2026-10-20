# Compatibility wrapper. v3 standardizes on JetBrains Mono fonts.
# Uses the pwsh.exe -File subprocess pattern, not a bare `&` call on a path
# string - see scripts/ci/dry-run.ps1's header for why (that pattern was
# found, 2026-10-20, to not reliably invoke a .ps1 by path at all in this
# repo's environment, on any of Windows/Linux/macOS).
& pwsh.exe -NoLogo -NoProfile -File (Join-Path $PSScriptRoot "41-install-fonts.ps1") @args
exit $LASTEXITCODE
