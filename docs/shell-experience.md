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

## zsh plugins, tmux, and ripgrep

Oh My Posh remains the single managed prompt engine (see above) - zsh gets a
small, specific set of extra plugins via
[zinit](https://github.com/zdharma-continuum/zinit) alongside it, not a
switch to Powerlevel10k or another prompt framework:

- `Aloxaf/fzf-tab` - fzf-driven `<Tab>` completion menu.
- `zsh-users/zsh-autosuggestions`
- `zsh-users/zsh-syntax-highlighting`

A managed Alacritty config (`shell/alacritty/architect.alacritty.toml`, Tokyo
Night colors, JetBrainsMono Nerd Font - ported from `Iskarioti/.dotfiles`, see
that file's own header for the two deliberate deviations from the source) is
deployed on every platform: `~/.config/alacritty/alacritty.toml` on macOS/
Linux (installed via `brew install --cask alacritty` on macOS, apt/dnf/pacman
on Linux - best-effort there, only useful with an actual display e.g. WSLg),
and `%APPDATA%\alacritty\alacritty.toml` on Windows (installed via
`windows/10-install-tools.ps1`, pinned to the taskbar - see
`docs/desktop-appearance.md`). Windows Terminal remains the *only* Windows
Terminal profile (PowerShell 7, per AGENTS.md rule 6) - Alacritty is an
additional, separately-pinned terminal application, not a replacement for
Windows Terminal's own configuration.

`scripts/posix/apply.sh` also deploys a managed tmux config
(`shell/tmux/architect.tmux.conf` -> `~/.config/tmux/tmux.conf`: vim-style
pane/window navigation, vi copy-mode, mouse on, a Tokyo Night theme via
[TPM](https://github.com/tmux-plugins/tpm) to match the Oh My Posh theme)
and a managed ripgrep config (`shell/ripgrep/architect.ripgreprc` ->
`~/.config/ripgrep/ripgreprc`, excludes `vendor/`/`node_modules/`,
`RIPGREP_CONFIG_PATH` set in both shell fragments). `apply.sh` clones tpm to
`~/.tmux/plugins/tpm` if missing; a fresh machine still needs one manual
`prefix + I` inside a tmux session to fetch the plugins themselves - tpm has
no non-interactive install path upstream.

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
