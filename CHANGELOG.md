# Changelog

## 3.0.0

- Rebuilt the workstation as a GitHub-first source-of-truth repository.
- Added one-command Windows and POSIX bootstrap entrypoints.
- Added platform adapters for Windows, Linux and macOS.
- Replaced rsync-style thinking with explicit cp/Copy-Item deployment.
- Added background autosync that validates, applies, commits and pushes the current branch.
- Added pre-commit validation and post-commit apply/push hooks.
- Added safe GitHub publication commands using GitHub CLI.
- Added AI-agent contracts for Codex, Claude, Kimi and Copilot.
- Added GitHub Actions validation on Windows, Linux and macOS.
- Standardized VS Code editor font on official JetBrains Mono.
- Standardized terminal font on JetBrainsMono Nerd Font Mono.
- Added cross-platform VS Code configuration and extension management.
- Added cross-platform Oh My Posh configuration.
- Added secret filename protection to autosync.
- Preserved Windows Terminal PowerShell-only architecture.
- Preserved Docker-inside-WSL architecture on Windows.
- Added global logical `workstation` command after bootstrap.

## 2.5

- Standardized Windows Terminal on exactly one explicit shell: PowerShell 7 GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}`.
- Made that PowerShell 7 profile the Windows Terminal default.
- Added an advanced Tokyo Night Windows Terminal configuration with centered 160×44 launch size.
- Added extensive keyboard-first tab, pane, navigation, incident-bookmark, export-buffer, search and font controls.
- Preserved `Ctrl+C` for shell interrupt and moved clipboard operations to `Ctrl+Shift+C/V`.
- Added command/prompt marks and a 32,767-line operational scrollback.
- Added global Meslo Nerd Font installation through the `NerdFonts` PowerShell resource with `AllUsers` scope.
- Added a safe Windows Terminal settings installer with automatic backup and JSON validation.
- Expanded the PowerShell profile for PSReadLine history/prediction, fzf, zoxide, Git, WSL, Docker, Azure, Kubernetes, Terraform and network diagnostics.
- Added CLM-aware Oh My Posh behavior and a minimal fallback prompt.
- Added `windows/46-shell-doctor.ps1`.
- Hardened the Oh My Posh path renderer against duplicate `spa/spa` paths.
- Documented RemoteSigned/MOTW handling without execution-policy bypasses.

## 2.4

- Replaced Starship with Oh My Posh as the workstation prompt engine.
- Added a compact Tokyo Night Storm-derived Oh My Posh theme.
- Preserved the one-line prompt and short `spa` path abbreviation.
- Added true right-side command duration and clock using an Oh My Posh `rprompt`.
- Retained ble.sh because current Oh My Posh Bash rprompt support uses it.
- Added supported PowerShell ConstrainedLanguage initialization without weakening App Control.
- Windows migration backs up Starship config and attempts to uninstall the WinGet Starship package.
- WSL migration backs up Starship config and removes only the repo-owned local Starship binary.
- Added migration documentation and Oh My Posh diagnostics.

## 2.3

- Added adaptive PowerShell Starship initialization.
- Fixed Starship startup under enterprise PowerShell ConstrainedLanguage.
- CLM now uses a direct `starship prompt` adapter instead of the generated PowerShell initializer that creates restricted .NET process types.
- Added CLM-safe zoxide wrappers.
- Windows shell installer reports the detected PowerShell language mode.
- App Control / WDAC / ConstrainedLanguage are never disabled or bypassed.

## v2.2

- Standardized advanced shell UX on Starship + Tokyo Night.
- Added compact two-component path rendering and engineering directory substitutions.
- Added Bash true right prompt with command duration and time using ble.sh.
- Added WSL shell bootstrap with fzf, zoxide, eza, bat, fd, ripgrep, direnv and tmux.
- Added enterprise-safe PowerShell 7 profile plus Starship/zoxide/fzf installer.
- Fixed WSL Windows-profile discovery for PowerShell ConstrainedLanguage environments.
- Hardened shared SSH configuration: common config copied into WSL; private keys remain OS-specific.
- Fixed Sysinternals package handling by using the Microsoft Store package instead of bypassing hash validation.
- Improved Windows package installation verification and failure reporting.
- Improved `platformctl doctor` with per-command timeouts, explicit TIMEOUT state, and separate Azure authentication status.

