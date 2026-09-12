$ErrorActionPreference = "Continue"
schtasks.exe /Delete /F /TN "WorkstationDevServicesAutostart" 2>$null
exit 0
