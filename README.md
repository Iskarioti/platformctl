# Systems & Platform Architect Workstation

A GitHub-first, fully automated, adaptive workstation for Windows, Linux and macOS.

The repository is the source of truth. Clone it on a new laptop, run one bootstrap
command, and the machine installs/adapts itself.

## New machine

### Windows

```powershell
git clone <repo-url>
cd system-platform-architect-workstation
.\bootstrap.ps1
```

### Linux / macOS

```bash
git clone <repo-url>
cd system-platform-architect-workstation
./bootstrap
```

After bootstrap:

```text
workstation validate
workstation apply
workstation doctor
workstation sync
workstation update
workstation autosync enable
```

## What is automated

- platform detection;
- package installation;
- PowerShell / bash / zsh shell setup;
- Oh My Posh Tokyo Night prompt;
- official JetBrains Mono for VS Code editor text;
- JetBrainsMono Nerd Font Mono for terminal text;
- Windows Terminal PowerShell-only configuration;
- VS Code settings and extensions;
- WSL and Docker-inside-WSL on Windows;
- Git hooks;
- validation;
- cp/Copy-Item configuration deployment;
- background commit/push synchronization to GitHub;
- AI-agent maintenance contract.

## GitHub source of truth

Normal commits are validated, applied and pushed automatically.

Uncommitted repository changes are picked up by the platform autosync service every
minute. Autosync validates first, applies with cp/Copy-Item, commits safe repository
changes and pushes the current branch. It never force-pushes.

## AI agents

Read:

- `AGENTS.md`
- `CLAUDE.md`
- `KIMI.md`
- `docs/ai-agent-maintenance.md`

The repository is designed to be maintained by Claude Code, Codex, Kimi and other
coding agents without giving them permission to weaken endpoint security or commit
secrets.

## Documentation

- `docs/architecture.md`
- `docs/new-machine.md`
- `docs/autosync.md`
- `docs/ai-agent-maintenance.md`
- `docs/fonts.md`
- `docs/windows-terminal.md`
- `docs/powershell-profile.md`
