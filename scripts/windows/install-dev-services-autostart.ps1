#Requires -Version 7.0
param(
    # ValueFromRemainingArguments: this script runs as a separate pwsh.exe
    # process (invoked via -File from services-autostart-control.ps1), and a
    # plain array bound to a named -Services parameter does not survive that
    # process boundary reliably - only the first element arrives. Splatting
    # the caller's array positionally (@Services, no -Services flag) into a
    # remaining-arguments parameter here is what actually works, confirmed by
    # a real failed run that silently installed a task for "redis" only.
    [Parameter(Position=0, ValueFromRemainingArguments=$true)]
    [string[]]$Services = @("redis", "redisinsight")
)

$ErrorActionPreference = "Stop"

# Docker's own restart:unless-stopped policy (set in each service's own
# compose.yaml) resumes these containers whenever the Docker daemon starts -
# but that daemon only starts if WSL itself is running. This Scheduled Task's
# only job is to wake WSL at logon and bring the target services up, the same
# division of responsibility as WorkstationDashboardAutostart (see
# install-dashboard-autostart.ps1): a restart policy alone does nothing until
# something actually starts the WSL instance.
#
# wsl.exe is a normal System32 binary (unlike pwsh.exe's MSIX Store alias case
# elsewhere in this repo), so a bare name is fine here.

$Distro = "Ubuntu-24.04"
$ServiceArgs = $Services -join " "
$TaskCommand = "wsl.exe -d $Distro -- bash -lc `"workstation services up $ServiceArgs`""

schtasks.exe /Create /F /SC ONLOGON /TN "WorkstationDevServicesAutostart" /TR $TaskCommand /RL LIMITED
if ($LASTEXITCODE -ne 0) { throw "Could not create dev-services autostart scheduled task." }

Write-Host "Dev-services autostart-at-logon task installed for: $ServiceArgs"
Write-Host "This only wakes WSL/starts the containers - the actual restart:unless-stopped"
Write-Host "policy already lives in each service's own compose.yaml."
