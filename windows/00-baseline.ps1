#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

Write-Host "=== Windows baseline ==="

Get-ComputerInfo | Select-Object WindowsProductName, WindowsVersion, OsBuildNumber, CsTotalPhysicalMemory
Write-Host "`n=== Virtualization ==="
systeminfo | Select-String "Hyper-V Requirements|Virtualization Enabled In Firmware"

Write-Host "`n=== Secure Boot ==="
try {
    Confirm-SecureBootUEFI
} catch {
    Write-Warning "Secure Boot state could not be read from this session/firmware."
}

Write-Host "`n=== BitLocker ==="
manage-bde -status C:

Write-Host "`n=== Device Guard / VBS ==="
Get-CimInstance -ClassName Win32_DeviceGuard -Namespace root\Microsoft\Windows\DeviceGuard |
    Select-Object SecurityServicesConfigured, SecurityServicesRunning, VirtualizationBasedSecurityStatus

Write-Host "`n=== WSL status ==="
wsl --status 2>$null
wsl --version 2>$null

Write-Host "`n=== Disk ==="
Get-Volume -DriveLetter C | Select-Object DriveLetter, FileSystemLabel,
    @{N="SizeGB";E={[math]::Round($_.Size/1GB,1)}},
    @{N="FreeGB";E={[math]::Round($_.SizeRemaining/1GB,1)}}

Write-Host "`nBaseline complete."
