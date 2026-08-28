# Windows Terminal — PowerShell-Only Platform Engineering Console

The workstation intentionally exposes **one Windows Terminal profile only**:

```text
PowerShell 7
{574e775e-4f2a-5b96-ac1e-a2962a402336}
```

That profile is also the `defaultProfile`.

WSL, Azure CLI, SSH, Docker, Kubernetes and Terraform are capabilities invoked
from PowerShell rather than separate Terminal profiles. This keeps the terminal
surface predictable while PowerShell remains the Windows control plane.

## Installation

First install the global Nerd Font from an elevated PowerShell 7 session:

```powershell
.\windows\41-install-global-nerd-font.ps1
```

Then install the Terminal configuration:

```powershell
.\windows\42-configure-windows-terminal.ps1
```

The Terminal installer backs up the existing `settings.json` before replacement.

## Window and visual design

- centered on launch;
- 160 columns × 44 rows;
- Tokyo Night Architect ANSI scheme;
- JetBrainsMono Nerd Font Mono at 11 pt;
- opaque rendering, no acrylic;
- 32,767 lines of scrollback;
- prompt marks visible on the scrollbar;
- MRU tab switching;
- subsequent launches reuse the existing Terminal window.

## Keybindings

### Shell safety

```text
Ctrl+C                  passed to PowerShell/applications (interrupt)
Ctrl+V                  passed to applications
Ctrl+Shift+C            copy
Ctrl+Shift+V            paste
```

### Core Terminal

```text
Ctrl+Shift+P            command palette
Ctrl+Shift+F            search scrollback
Ctrl+Shift+,            open settings.json
Ctrl+Shift+Enter        focus mode
Ctrl+Alt+Space          summon/hide Windows Terminal
```

### Tabs

```text
Ctrl+Shift+T            new PowerShell 7 tab
Ctrl+Shift+W            close pane/tab
Ctrl+Tab                next tab
Ctrl+Shift+Tab          previous tab
Ctrl+Shift+R            rename tab
Ctrl+Shift+Left/Right   move tab
Ctrl+Alt+1..8           jump directly to tab 1..8
```

### Panes

```text
Alt+Shift+D             automatic duplicate split
Alt+Shift+V             vertical duplicate split
Alt+Shift+H             horizontal duplicate split
Alt+Shift+Enter         zoom active pane
Alt+Arrow               move focus between panes
Alt+Shift+Arrow         resize pane
```

### Command history / incident work

```text
Ctrl+Alt+Up             previous command mark
Ctrl+Alt+Down           next command mark
Ctrl+Alt+M              add troubleshooting bookmark
Ctrl+Shift+E            export complete terminal buffer
Ctrl+Shift+L            clear buffer
Shift+F10               context menu
```

### Font

```text
Ctrl+=                  increase
Ctrl+-                  decrease
Ctrl+0                  reset
```

## Why there is no Ubuntu profile

PowerShell is the only Terminal shell by design. Enter the Linux engineering plane
from the same shell:

```powershell
linux
```

or execute individual WSL commands:

```powershell
wu uname -a
wu ip addr
docker ps
dc ps
ops
```

This preserves one consistent Windows Terminal entry point while keeping the actual
Docker Engine and Linux engineering workload inside Ubuntu 24.04.
