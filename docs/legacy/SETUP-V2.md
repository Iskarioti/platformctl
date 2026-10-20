# Legacy v2 Setup Notes

> v3 uses `bootstrap.ps1` on Windows or `./bootstrap` on Linux/macOS. See `docs/new-machine.md` and `docs/architecture.md`.

# Workstation Setup v2

## Downloaded ZIPs and RemoteSigned

On the managed Windows endpoint, unblock the downloaded ZIP **before extraction**:

```powershell
Unblock-File .\system-platform-architect-workstation-v2.5.zip
```

Then extract it. Do not weaken the execution policy and do not use a process-level
Bypass merely to run the workstation scripts.

If the archive was already extracted, unblock the extracted repository once:

```powershell
Get-ChildItem .\system-platform-architect-workstation-v2.5 -Recurse -File |
    Unblock-File
```

## Windows Terminal + PowerShell 7

The Windows terminal layer is PowerShell-only. PowerShell 7
`{574e775e-4f2a-5b96-ac1e-a2962a402336}` is the only explicit Terminal profile and
the default.

Install the global Meslo Nerd Font from an **elevated PowerShell 7** session:

```powershell
.\windows\41-install-global-nerd-font.ps1
```

The font workflow uses the `NerdFonts` PSResource and installs `Meslo` with
`-Scope AllUsers`. The script deliberately does not mark PSGallery trusted.

Install the Terminal configuration:

```powershell
.\windows\42-configure-windows-terminal.ps1
```

Install the advanced PowerShell shell:

```powershell
.\windows\45-shell-experience.ps1
```

Validate it:

```powershell
.\windows\46-shell-doctor.ps1
```

Close all Windows Terminal windows and open a fresh PowerShell 7 session after
configuration. On ConstrainedLanguage endpoints, do not use `. $PROFILE` as the
normal profile reload mechanism.

See `docs/windows-terminal.md` and `docs/powershell-profile.md`.

## Architecture

Windows:
- Teams, Outlook, Office, Edge, VPN/security
- VS Code UI, PowerShell, Wireshark, Sysinternals
- ChatGPT/Claude interactive browser/desktop usage
- OpenVINO NPU lab only when testing Intel AI Boost

WSL:
- Git, SSH, Azure CLI
- Docker Engine + Docker Compose
- network diagnostics
- platformctl
- shared local AI runtime orchestration

Dev Containers:
- light development
- application runtimes and project dependencies
- Terraform/Ansible/kubectl/Helm versions
- Codex CLI and Claude Code in trusted projects
- tests, linting, security tooling

Docker services:
- PostgreSQL, Redis, Kafka, etc.
- shared Ollama runtime for Gemma and other local models

Azure:
- distributed/high-availability labs
- heavy AI/GPU workloads
- production-like validation

## Resource profiles

Normal day:
- WSL 12 GB RAM / 8 vCPU / 4 GB swap

AI lab:
- WSL 16 GB RAM / 8 vCPU / 6 GB swap
- close unnecessary browser tabs/Teams if testing a larger model
- switch back to default after the lab

Commands:
```powershell
.\windows\25-set-wsl-profile.ps1 -Profile default
.\windows\25-set-wsl-profile.ps1 -Profile ai-lab
```

Each switch performs `wsl --shutdown`.

## AI separation

Interactive reasoning:
- ChatGPT and Claude on Windows/web/desktop

Coding:
- Codex CLI and Claude Code inside trusted Dev Containers

Local model runtime:
- dedicated Docker Compose stack in `ai-runtime/`
- model weights in Docker volume `ollama-models`
- projects connect over the external Docker network `ai-runtime`

NPU:
- native Windows OpenVINO lab
- separate from normal Dev Container and Ollama workflow


## Advanced shell experience

The standard prompt is **Oh My Posh + Tokyo Night Storm**. It is intentionally compact and one-line. The left side shows OS, a short directory, Git and detected engineering context. Command duration and time render on the far right through an Oh My Posh `rprompt`; Bash uses ble.sh for that right-prompt support.

WSL:
```bash
./wsl/install-shell-experience.sh
exec bash
```

PowerShell 7:
```powershell
.\windows\45-shell-experience.ps1
```

The PowerShell profile is CLM-aware and does not weaken App Control. Meslo Nerd Font is installed globally through the NerdFonts PowerShell resource; font files are not distributed by this repository. Windows Terminal is configured as a PowerShell-only engineering console.

See `docs/shell-experience.md`.

## Troubleshooting changes incorporated

- `wsl/configure-shared-git-ssh.sh` discovers the Windows profile through `cmd.exe`, avoiding PowerShell static .NET calls blocked by ConstrainedLanguage.
- WSL SSH copies the common Windows SSH config into the Linux filesystem with Linux-safe permissions; private keys remain WSL-specific.
- Windows baseline uses the Microsoft Store Sysinternals Suite ID (`9P7KNL5RWT25`) instead of bypassing a stale WinGet archive hash.
- `platformctl doctor` reports command timeouts separately from failures and checks Azure CLI installation separately from Azure authentication.
