# Workstation Architecture v3

## Principle

Git is the source of truth. The live machine is a deployment target.

```text
GitHub
  ^
  | push current branch
  |
Repository source
  |
  +--> validate
  |
  +--> apply with cp / Copy-Item
  |
  +--> live Windows / Linux / macOS configuration
```

There is no rsync-based mirroring and no reverse-copying of arbitrary live files into
the repository.

## One-command bootstrap

Windows:

```powershell
git clone <repo>
cd system-platform-architect-workstation
.\bootstrap.ps1
```

Linux/macOS:

```bash
git clone <repo>
cd system-platform-architect-workstation
./bootstrap
```

After bootstrap, use the global logical command:

```text
workstation validate
workstation apply
workstation doctor
workstation sync
workstation autosync enable
```

## Automatic change flow

Background autosync runs every minute:

1. detect a dirty repository;
2. validate source;
3. apply source to live locations with cp/Copy-Item;
4. stage tracked changes plus allowlisted new files;
5. refuse obvious secret-bearing filenames;
6. commit;
7. rebase from the current remote branch;
8. push the current branch without force.

Normal manual/agent commits are also validated by `pre-commit` and automatically
applied/pushed by `post-commit`.

## Agent-friendly maintenance

All agents read `AGENTS.md`. Claude additionally reads `CLAUDE.md`; Kimi reads
`KIMI.md`; GitHub Copilot reads `.github/copilot-instructions.md`.

Agents change canonical source, not deployed configuration.

## Platform adapters

- Windows: winget, PowerShell 7, Windows Terminal, WSL, PowerShell profile.
- Linux: apt/dnf/pacman, bash, native Docker, VS Code when available.
- macOS: Homebrew, zsh, native tools, VS Code.

Shared user experience:
- Oh My Posh Tokyo Night theme;
- official JetBrains Mono for editor text;
- JetBrainsMono Nerd Font Mono for terminals;
- zoxide/fzf/Git helpers;
- GitHub-backed source of truth.
