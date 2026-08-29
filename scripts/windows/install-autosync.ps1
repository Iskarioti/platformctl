#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Script = Join-Path $Root "scripts\common\autosync.ps1"

# Resolve the real pwsh.exe binary path rather than relying on the bare
# "pwsh.exe" name. When PowerShell resolves through a Store/MSIX App
# Execution Alias (common on machines where PowerShell was installed from
# the Microsoft Store), Task Scheduler's CreateProcess call cannot follow
# that alias reparse point and fails with ERROR_FILE_NOT_FOUND even though
# the same command works fine when typed interactively. Embedding the
# resolved absolute path sidesteps that.
$PwshCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue
if (-not $PwshCommand) {
    throw "pwsh.exe could not be resolved; cannot install autosync scheduled task."
}
$PwshPath = $PwshCommand.Source

$TaskCommand = "`"$PwshPath`" -NoLogo -NoProfile -File `"$Script`" -Once"
schtasks.exe /Create /F /SC MINUTE /MO 1 /TN "WorkstationSetupAutoSync" /TR $TaskCommand
if ($LASTEXITCODE -ne 0) { throw "Could not create autosync scheduled task." }

Write-Host "Autosync enabled: every minute, validate -> apply -> commit -> push current branch."
