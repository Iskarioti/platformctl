#Requires -Version 7.0
[CmdletBinding()]
param(
    [switch]$WhatIf,
    [switch]$Restart
)

# Enforces this repo's device naming convention: LAP-<BIOS_SERIAL> for laptops,
# DSK-<BIOS_SERIAL> for desktops. Idempotent - checks the current name first and
# only renames on a real mismatch. Never restarts automatically (a rename needs a
# restart to fully take effect everywhere, but that's disruptive enough to want
# an explicit -Restart, not a default).

$ErrorActionPreference = "Stop"

# DMTF chassis-type codes (Win32_SystemEnclosure.ChassisTypes / Linux's
# /sys/class/dmi/id/chassis_type share the same numbering) - used before
# falling back to PCSystemType/battery presence, since a handful of unusual
# enclosures (docking stations, all-in-ones) don't fit either list cleanly.
$LaptopChassisTypes = @(8, 9, 10, 11, 14, 30, 31, 32)
$DesktopChassisTypes = @(3, 4, 5, 6, 7, 15, 16, 35)

function Get-DeviceKind {
    $Enclosure = Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue
    $ComputerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue
    $Battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue

    $ChassisType = $null
    if ($Enclosure -and $Enclosure.ChassisTypes) { $ChassisType = $Enclosure.ChassisTypes[0] }

    if ($ChassisType -and ($LaptopChassisTypes -contains $ChassisType)) { return "laptop" }
    if ($ChassisType -and ($DesktopChassisTypes -contains $ChassisType)) { return "desktop" }

    # Fallback for an enclosure type this repo doesn't recognize: PCSystemType
    # 2 = Mobile, and battery presence is a strong laptop signal either way.
    if ($ComputerSystem -and $ComputerSystem.PCSystemType -eq 2) { return "laptop" }
    if ($Battery) { return "laptop" }

    return "desktop"
}

function Get-BiosSerial {
    $Bios = Get-CimInstance -ClassName Win32_BIOS -ErrorAction SilentlyContinue
    if (-not $Bios -or -not $Bios.SerialNumber) { return $null }

    $Serial = $Bios.SerialNumber.Trim()
    # Placeholder values real OEM firmware ships when no serial was ever
    # programmed (common on white-box/VM hardware) - never build a name from these.
    $GenericValues = @(
        "", "0", "None", "System Serial Number", "To Be Filled By O.E.M.",
        "Default string", "Not Specified", "Not Applicable", "Serial Number"
    )
    if ($GenericValues -contains $Serial) { return $null }
    return $Serial
}

$Kind = Get-DeviceKind
$Serial = Get-BiosSerial

if (-not $Serial) {
    Write-Warning "BIOS serial number is missing or a generic placeholder - refusing to compute a device name from it."
    exit 1
}

$Prefix = if ($Kind -eq "laptop") { "LAP" } else { "DSK" }
$TargetName = "$Prefix-$Serial"

# Windows computer names are capped at 15 characters (the NetBIOS limit) -
# Rename-Computer would otherwise silently truncate or reject a longer name.
# Truncate the serial to fit rather than let that happen invisibly.
$MaxLength = 15
if ($TargetName.Length -gt $MaxLength) {
    $AvailableForSerial = $MaxLength - ($Prefix.Length + 1)
    $TruncatedSerial = $Serial.Substring(0, $AvailableForSerial)
    Write-Warning "Computed name '$TargetName' exceeds the 15-character Windows computer-name limit - truncating serial to fit: '$Prefix-$TruncatedSerial'."
    $TargetName = "$Prefix-$TruncatedSerial"
}

$CurrentName = $env:COMPUTERNAME

Write-Host "Device kind:  $Kind"
Write-Host "BIOS serial:  $Serial"
Write-Host "Current name: $CurrentName"
Write-Host "Target name:  $TargetName"

if ($CurrentName -eq $TargetName) {
    Write-Host "Name already matches the target convention - nothing to do." -ForegroundColor Green
    exit 0
}

if ($WhatIf) {
    Write-Host "Would rename '$CurrentName' -> '$TargetName' (-WhatIf: no change made)." -ForegroundColor Yellow
    exit 0
}

Write-Host "Renaming '$CurrentName' -> '$TargetName'..." -ForegroundColor Cyan
Rename-Computer -NewName $TargetName -Force -ErrorAction Stop

if ($Restart) {
    Write-Host "Restarting now to apply the rename..." -ForegroundColor Cyan
    Restart-Computer -Force
} else {
    Write-Host "Renamed to '$TargetName'. A RESTART IS REQUIRED for this to take full" -ForegroundColor Yellow
    Write-Host "effect (network identity, some management tooling) - not restarting" -ForegroundColor Yellow
    Write-Host "automatically; pass -Restart to do so, or restart manually when convenient." -ForegroundColor Yellow
}
