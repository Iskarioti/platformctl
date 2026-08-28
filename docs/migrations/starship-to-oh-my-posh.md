# Starship to Oh My Posh migration

Version 2.4 changes the workstation prompt engine from Starship to Oh My Posh.

## Windows

Run:

```powershell
.\windows\45-shell-experience.ps1
```

The script:

1. installs Oh My Posh with WinGet;
2. backs up `~/.config/starship.toml`;
3. attempts to uninstall the WinGet Starship package;
4. installs the Tokyo Night theme;
5. backs up and replaces the PowerShell profile.

Do not dot-source an older Starship profile in the current session. Open a fresh
PowerShell 7 window after migration.

## WSL

Run:

```bash
./wsl/install-shell-experience.sh
exec bash
```

The script backs up the Starship configuration and removes only the
repo-owned `~/.local/bin/starship` executable. ble.sh is retained because it is also
used by Oh My Posh for Bash right-prompt support.

## Rollback

All replaced profile/configuration files are backed up with timestamps. Restoring a
backup is preferable to weakening execution policy or App Control.
