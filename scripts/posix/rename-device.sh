#!/usr/bin/env bash
set -uo pipefail

# Enforces this repo's device naming convention: LAP-<BIOS_SERIAL> for laptops,
# DSK-<BIOS_SERIAL> for desktops. Idempotent - checks the current name first and
# only renames on a real mismatch. Mirrors scripts/common/rename-device.ps1's
# Windows logic; see docs/desktop-appearance.md for the shared rationale
# (naming convention, why a mismatch/generic serial refuses rather than guesses).
#
# NOT run under WSL: WSL2's DMI data reflects the lightweight Hyper-V VM it runs
# in, not the physical host's real BIOS serial - the Windows host is already
# renamed by the .ps1 above, and WSL itself isn't "a device" of its own to name.

WHAT_IF=0
DO_RESTART=0
for arg in "$@"; do
  [[ "$arg" == "--what-if" ]] && WHAT_IF=1
  [[ "$arg" == "--restart" ]] && DO_RESTART=1
done

is_generic_serial() {
  case "$1" in
    ""|"0"|"None"|"System Serial Number"|"To Be Filled By O.E.M."|"Default string"|"Not Specified"|"Not Applicable"|"Serial Number") return 0 ;;
    *) return 1 ;;
  esac
}

if [[ "$(uname -s)" == "Darwin" ]]; then
  Model="$(sysctl -n hw.model 2>/dev/null || echo "")"
  case "$Model" in
    MacBook*) Kind="laptop" ;;
    *) Kind="desktop" ;;
  esac

  Serial="$(ioreg -rd1 -c IOPlatformExpertDevice 2>/dev/null | awk -F'"' '/IOPlatformSerialNumber/{print $4}')"
  CurrentName="$(scutil --get ComputerName 2>/dev/null || echo "")"
  MaxLength=63   # LocalHostName's DNS-label limit; far more headroom than Windows's 15.

  rename() {
    sudo scutil --set ComputerName "$1"
    sudo scutil --set HostName "$1"
    sudo scutil --set LocalHostName "$1"
  }
elif [[ "$(uname -s)" == "Linux" ]]; then
  if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "Running under WSL - the physical host's BIOS serial isn't reliably" >&2
    echo "visible here (WSL2's DMI data reflects its own lightweight VM), and" >&2
    echo "WSL isn't a separate device to name. Rename the Windows host instead" >&2
    echo "(scripts/common/rename-device.ps1) - skipping." >&2
    exit 0
  fi

  ChassisType="$(cat /sys/class/dmi/id/chassis_type 2>/dev/null || echo "")"
  case "$ChassisType" in
    8|9|10|11|14|30|31|32) Kind="laptop" ;;
    3|4|5|6|7|15|16|35) Kind="desktop" ;;
    *)
      if compgen -G "/sys/class/power_supply/BAT*" >/dev/null 2>&1; then
        Kind="laptop"
      else
        Kind="desktop"
      fi
      ;;
  esac

  Serial="$(cat /sys/class/dmi/id/product_serial 2>/dev/null || true)"
  if [[ -z "$Serial" ]]; then
    Serial="$(sudo dmidecode -s system-serial-number 2>/dev/null || true)"
  fi
  CurrentName="$(hostnamectl hostname 2>/dev/null || hostname)"
  MaxLength=64   # Linux hostname length limit.

  rename() {
    sudo hostnamectl set-hostname "$1"
  }
else
  echo "Unsupported platform for rename-device.sh: $(uname -s)" >&2
  exit 3
fi

Serial="$(echo "$Serial" | xargs)"   # trim whitespace
if is_generic_serial "$Serial"; then
  echo "BIOS/hardware serial number is missing or a generic placeholder - refusing to compute a device name from it." >&2
  exit 1
fi

Prefix="LAP"
[[ "$Kind" == "desktop" ]] && Prefix="DSK"
TargetName="${Prefix}-${Serial}"

if [[ ${#TargetName} -gt $MaxLength ]]; then
  AvailableForSerial=$(( MaxLength - ${#Prefix} - 1 ))
  TruncatedSerial="${Serial:0:$AvailableForSerial}"
  echo "Computed name '$TargetName' exceeds the $MaxLength-character limit - truncating serial to fit: '${Prefix}-${TruncatedSerial}'." >&2
  TargetName="${Prefix}-${TruncatedSerial}"
fi

echo "Device kind:  $Kind"
echo "Serial:       $Serial"
echo "Current name: $CurrentName"
echo "Target name:  $TargetName"

if [[ "$CurrentName" == "$TargetName" ]]; then
  echo "Name already matches the target convention - nothing to do."
  exit 0
fi

if [[ "$WHAT_IF" -eq 1 ]]; then
  echo "Would rename '$CurrentName' -> '$TargetName' (--what-if: no change made)."
  exit 0
fi

echo "Renaming '$CurrentName' -> '$TargetName'..."
rename "$TargetName"

if [[ "$DO_RESTART" -eq 1 ]]; then
  echo "Restarting now to apply the rename..."
  if [[ "$(uname -s)" == "Darwin" ]]; then
    sudo shutdown -r now
  else
    sudo systemctl reboot
  fi
else
  echo "Renamed to '$TargetName'. A restart is recommended for this to take full" >&2
  echo "effect everywhere - not restarting automatically; pass --restart to do so." >&2
fi
