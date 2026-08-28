# Advanced Shell Experience

The workstation standardizes on **Oh My Posh + Tokyo Night Storm**.

The canonical prompt is derived from the official `tokyonight_storm` palette, but
is deliberately more compact for engineering work.

## Design

- One-line prompt.
- Short two-level path display.
- Long workstation repository names are abbreviated to `spa`.
- Git branch and concise status only when inside Git.
- Python, Node.js, Go, Rust and Terraform context only when relevant.
- Kubernetes context on wider terminals, with production-like contexts highlighted.
- Azure subscription and Docker context only on sufficiently wide terminals and
  with strict per-segment timeouts so they cannot stall the prompt.
- Previous command duration and current time render on the far right.
- `ble.sh` remains installed because current Oh My Posh Bash `rprompt` support uses it.
- PowerShell uses Oh My Posh's supported ConstrainedLanguage behavior.

Example:

```text
󰕈 …/spa/windows  main ❯ task test                         󰔛 4.8s  23:52
```

## Canonical theme

```text
shell/oh-my-posh/tokyonight-architect.omp.json
```

It uses the Tokyo Night Storm palette:

```text
background  #24283b
red         #f7768e
green       #9ece6a
yellow      #e0af68
blue        #7aa2f7
cyan        #7dcfff
magenta     #bb9af7
```

## Ubuntu / WSL

```bash
./wsl/install-shell-experience.sh
exec bash
```

The script installs/configures:

- Oh My Posh
- Tokyo Night prompt
- ble.sh for Bash right-prompt support
- bash-completion
- fzf
- zoxide
- eza
- bat
- fd
- ripgrep
- direnv
- tmux
- engineering aliases and functions

The previous repo-owned `~/.local/bin/starship` binary is removed and
`~/.config/starship.toml` is backed up before migration.

## PowerShell 7

```powershell
.\windows\45-shell-experience.ps1
```

The script installs:

- Oh My Posh
- zoxide
- fzf

It backs up the current PowerShell profile, installs the managed profile and migrates
the previous Starship configuration. By default it also attempts to uninstall the
WinGet Starship package. Use `-KeepStarship` only if another workflow still needs it.

## PowerShell ConstrainedLanguage

The workstation does **not** disable or weaken App Control, WDAC or
ConstrainedLanguage.

Oh My Posh explicitly supports PowerShell ConstrainedLanguage. Its limitation is
that it cannot use .NET APIs to switch the console to UTF-8. The managed profile uses
the native `chcp.com 65001` command before initialization and sets
`POSH_CONSTRAINED_LANGUAGE=1`, avoiding prohibited .NET calls.

The Oh My Posh streaming implementation also falls back to a per-prompt process in
ConstrainedLanguage, which is supported behavior.

## Right prompt

The theme uses an Oh My Posh `rprompt` block:

```text
left prompt                                    right prompt
󰕈 …/hub/backend  main ❯                     󰔛 3.2s  23:52
```

Current Oh My Posh supports `rprompt` on PowerShell and on Bash with ble.sh.

## Font

Use a Nerd Font in Windows Terminal and the VS Code integrated terminal. Font files
are intentionally not included in this repository.

## Diagnostics

```bash
oh-my-posh version
oh-my-posh get shell
oh-my-posh debug --config ~/.config/oh-my-posh/tokyonight-architect.omp.json
```

PowerShell:

```powershell
oh-my-posh version
oh-my-posh get shell
oh-my-posh debug --config "$HOME\.config\oh-my-posh\tokyonight-architect.omp.json"
```

## Useful commands

Bash:

```bash
project ~/src/company
gbs
ops
z tooling
```

PowerShell:

```powershell
wstatus
dev hub-backend
dps
azctx
```


## Version 2.5 Windows shell integration

Windows now has three explicit shell setup stages:

```powershell
# Administrator
.\windows\41-install-global-nerd-font.ps1

# Standard user
.\windows\42-configure-windows-terminal.ps1
.\windows\45-shell-experience.ps1

# Validation
.\windows\46-shell-doctor.ps1
```

The Windows Terminal configuration is intentionally PowerShell-only. PowerShell 7
GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}` is the only explicit profile and the
default profile.

See:

- `docs/windows-terminal.md`
- `docs/powershell-profile.md`
