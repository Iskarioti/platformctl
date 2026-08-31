#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Script = Join-Path $Root "scripts\common\autosync.ps1"
$HiddenRunner = Join-Path $PSScriptRoot "run-hidden.vbs"

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

# Route through wscript.exe + run-hidden.vbs rather than launching pwsh.exe
# directly - see run-hidden.vbs for why a bare scheduled pwsh.exe task
# flashes a visible console window every run regardless of the task's own
# "Hidden" setting.
$TaskCommand = "wscript.exe //B `"$HiddenRunner`" `"$PwshPath`" -NoLogo -NoProfile -File `"$Script`" -Once"
schtasks.exe /Create /F /SC MINUTE /MO 5 /TN "WorkstationSetupAutoSync" /TR $TaskCommand
if ($LASTEXITCODE -ne 0) { throw "Could not create autosync scheduled task." }

Write-Host "Autosync enabled: every 5 minutes (hidden), validate -> apply -> commit -> push current branch."
