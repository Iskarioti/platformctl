# platformctl shell configuration fix v3.2.1

This overlay fixes the WSL/Zsh shell mismatch and cleans the Tokyo Night Oh My Posh prompt.

Changes:
- Linux now deploys both managed Bash and Zsh shell fragments.
- Zsh uses version-compatible fzf integration instead of assuming `fzf --zsh` exists.
- Zsh and Bash both include `workspace`, project navigation and source-root helpers.
- Oh My Posh is the only managed prompt engine.
- Tokyo Night prompt is simplified to OS/path/Git on the left, command prompt on a second line, and contextual runtime/time information on the right.
- Git status no longer prints confusing zero counters/deletion totals.

Apply from PowerShell:

```powershell
pwsh.exe -NoLogo -NoProfile -File .\apply-to-platformctl.ps1 `
  -RepoPath "C:\Users\AndrewKariuki\OneDrive - WIOCC\Documents\platformctl"
```

Then validate:

```powershell
cd "C:\Users\AndrewKariuki\OneDrive - WIOCC\Documents\platformctl"
pwsh.exe -NoLogo -NoProfile -File .\setup.ps1 validate
```

Inside WSL, from the platformctl repository:

```bash
./setup apply
exec zsh
```

One-time live cleanup: remove the legacy Starship initialization block from `~/.zshrc`. Keep the `# >>> workstation-managed >>>` block. The managed configuration does not initialize Starship.

Verify:

```bash
zsh -lic 'echo Zsh startup clean'
type workspace
echo "$POSH_THEME"
command -v oh-my-posh
```
