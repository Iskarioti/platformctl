$ErrorActionPreference = "Continue"
schtasks.exe /Delete /F /TN "WorkstationDashboardAutostart" 2>$null
exit 0
