$ErrorActionPreference = "Continue"

Write-Host "=== Windows workstation health ==="
Write-Host ("Time: {0}" -f (Get-Date -Format o))

Write-Host "`nWSL:"
wsl --status
wsl --list --verbose

Write-Host "`nStorage:"
Get-Volume -DriveLetter C | Select DriveLetter,
    @{N="FreeGB";E={[math]::Round($_.SizeRemaining/1GB,1)}},
    @{N="TotalGB";E={[math]::Round($_.Size/1GB,1)}}

Write-Host "`nNetwork:"
Get-NetIPConfiguration | Where-Object {$_.IPv4Address} |
    Select InterfaceAlias, IPv4Address, IPv4DefaultGateway

Write-Host "`nSecurity:"
try { "SecureBoot: $(Confirm-SecureBootUEFI)" } catch { "SecureBoot: unable to query" }
manage-bde -status C: | Select-String "Conversion Status|Percentage Encrypted|Protection Status"


Write-Host "`nPowerShell:"
Write-Host "Version: $($PSVersionTable.PSVersion)"
Write-Host "LanguageMode: $($ExecutionContext.SessionState.LanguageMode)"
Write-Host "Profile: $PROFILE"

Write-Host "`nTerminal/shell tools:"
foreach ($Tool in @("oh-my-posh","zoxide","fzf","git","az","wsl","code")) {
    $Command = Get-Command $Tool -ErrorAction SilentlyContinue
    if ($Command) {
        Write-Host ("PASS {0}" -f $Tool)
    } else {
        Write-Warning ("MISSING {0}" -f $Tool)
    }
}
