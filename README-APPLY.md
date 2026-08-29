# platformctl Editor Management v3.3.0

This overlay adds a governed editor layer to the existing `platformctl` setup without
replacing the current development-enforcement, Docker-services, shell or WSL work.

## What is added

- Neovim 0.12.4, installed user-locally in WSL/Linux.
- Primary `platform` profile based on LazyVim.
- Alternate isolated NvChad v2.5 profile.
- Plugin-free minimal Neovim profile.
- Plugin-free Vim rescue configuration.
- Tokyo Night primary Neovim theme.
- Infrastructure-aware editor integration for Ansible, Docker, Terraform, YAML/JSON,
  Python, TypeScript, SQL, Markdown, Go and Rust.
- `NVIM_APPNAME` isolation between Neovim profiles.
- `workstation editor ...` lifecycle commands.
- Windows `workstation editor ...` delegation into Ubuntu-24.04.
- Linux bootstrap integration.
- No secrets, tokens, SSH keys or database passwords in editor configuration.
- No project-local Neovim config execution by default.
- `cp` / `Copy-Item` only. No rsync.

## Apply from PowerShell

Extract the archive outside the repository, then:

```powershell
pwsh.exe `
  -NoLogo `
  -NoProfile `
  -File ".\apply-to-platformctl.ps1" `
  -RepoPath "C:\Users\AndrewKariuki\OneDrive - WIOCC\Documents\platformctl"
```

The installer backs up every existing file it edits under:

```text
platformctl\.state\editor-upgrade-backup-YYYYMMDD-HHMMSS\
```

Then validate:

```powershell
cd "C:\Users\AndrewKariuki\OneDrive - WIOCC\Documents\platformctl"

pwsh.exe -NoLogo -NoProfile -File ".\setup.ps1" validate
```

## Install inside WSL

```powershell
wsl.exe -d Ubuntu-24.04 --cd ~
```

Then:

```bash
workstation editor install
workstation editor doctor
workstation editor list
```

The default editor profile is `platform`.

Switch profile:

```bash
workstation editor profile nvchad
nvim
```

Return to the main profile:

```bash
workstation editor profile platform
nvim
```

Direct launchers are always available:

```bash
nvim-platform
nvim-chad
nvim-minimal
vim
```

Pre-warm the primary plugin set:

```bash
workstation editor sync platform
```

## Bootstrap behavior

After this update, future Linux/WSL bootstrap runs automatically install the pinned
Neovim binary and deploy all editor profiles. Plugin synchronization is still lazy:
the first editor launch (or `workstation editor sync`) downloads plugins.

## Notes

LazyVim currently requires Neovim >= 0.11.2. The overlay pins Neovim 0.12.4.

NvChad uses a separate `NVIM_APPNAME=nvim-nvchad` profile and does not overwrite the
primary LazyVim profile.

Traditional Vim remains intentionally plugin-free so it is dependable during recovery,
SSH troubleshooting and minimal-system work.
