#Requires -RunAsAdministrator
$ErrorActionPreference = "Stop"

wsl --update
wsl --set-default-version 2

$installed = (wsl --list --quiet) -join "`n"
if ($installed -notmatch "Ubuntu-24.04") {
    wsl --install -d Ubuntu-24.04
    Write-Host "Ubuntu installation requested. Reboot if Windows asks, then start Ubuntu and create your Linux user."
} else {
    Write-Host "Ubuntu-24.04 already installed."
}

wsl --list --verbose
