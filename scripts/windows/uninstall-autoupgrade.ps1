$ErrorActionPreference = "Continue"
Unregister-ScheduledTask -TaskName "WorkstationAutoUpgrade" -Confirm:$false -ErrorAction SilentlyContinue
exit 0
