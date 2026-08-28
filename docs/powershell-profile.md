# Advanced PowerShell 7 Profile

The PowerShell profile is the Windows control-plane shell for development,
operations and platform engineering.

## Core capabilities

- PSReadLine incremental history with history prediction and ListView.
- Fast history search: `Ctrl+R` / `Ctrl+S`.
- Menu completion: `Tab` / `Ctrl+Space`.
- Word and line navigation shortcuts.
- Oh My Posh + Tokyo Night with a CLM-safe fallback.
- zoxide direct wrappers under ConstrainedLanguage.
- fzf project and Git branch selection.
- Git shorthand.
- WSL / Linux / tmux helpers.
- Docker and Docker Compose delegated to Ubuntu 24.04.
- Azure subscription/context helpers.
- Kubernetes and Terraform shorthand.
- Windows networking and route diagnostics.
- Toolchain status reporting.

## High-value commands

```text
Navigation
----------
.. / ... / ....
mkcd <path>
croot
fcd [root]
z <query>
zi

Git
---
gs ga gaa gc gca gp gl gf gd gds gb gsw glog
gbranch

Linux / WSL
-----------
w
wu <command>
linux
ops
wstatus
wstop

Docker in WSL
-------------
docker ...
d ...
dc ...
dps
dpa
ddf
dlogs <container>
dex <container> [shell]

Azure
-----
azctx
azsubs
azuse <subscription>
azgroups

Kubernetes
----------
k
kgp
kga
kctx
kns <namespace>

Terraform
---------
tf
tfi
tfp
tfa
tffmt
tfv

Diagnostics
-----------
myip
listen
tcp <host> <port>
trace <host>
dns <name> [type]
routes
toolversions
```

## ConstrainedLanguage

The profile does not disable execution policy, App Control, WDAC or
ConstrainedLanguage.

Under CLM:

- `POSH_CONSTRAINED_LANGUAGE=1` is set before Oh My Posh initialization;
- native `chcp.com` is used instead of restricted static .NET encoding calls;
- Oh My Posh streaming is disabled for simpler locked-down operation;
- zoxide is used through direct wrapper functions instead of evaluating its
  generated PowerShell initializer;
- if Oh My Posh initialization fails, a minimal local prompt is used so shell
  startup remains usable.

On managed CLM endpoints, **do not use `. $PROFILE` as the normal reload
mechanism**. Close the PowerShell process and open a new PowerShell 7 tab.
