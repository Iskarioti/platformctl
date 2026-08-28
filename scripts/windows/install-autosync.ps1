#Requires -Version 7.0
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$Script = Join-Path $Root "scripts\common\autosync.ps1"

$TaskCommand = "pwsh.exe -NoLogo -NoProfile -File `"$Script`" -Once"
schtasks.exe /Create /F /SC MINUTE /MO 1 /TN "WorkstationSetupAutoSync" /TR $TaskCommand
if ($LASTEXITCODE -ne 0) { throw "Could not create autosync scheduled task." }

Write-Host "Autosync enabled: every minute, validate -> apply -> commit -> push current branch."
