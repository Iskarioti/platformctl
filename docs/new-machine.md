# New Machine

## First machine: publish the repository

After extracting/downloading this repository and initializing Git:

```bash
git init
git add .
git commit -m "feat: reproducible workstation v3"
```

Then:

```text
workstation publish
```

The default publish target is a private GitHub repository named
`system-platform-architect-workstation`.

## Any later machine

Windows:

```powershell
git clone <your-repository-url>
cd system-platform-architect-workstation
.\bootstrap.ps1
```

Linux or macOS:

```bash
git clone <your-repository-url>
cd system-platform-architect-workstation
./bootstrap
```

Bootstrap installs platform prerequisites, fonts, prompt, editor configuration,
Git hooks, global workstation command and background autosync.

## What "ready to work" means

After bootstrap completes on any of the three platforms, without any further manual
setup, you can immediately:

```bash
workstation project init fastapi-service my-api --area company
workstation project open my-api
```

Bootstrap ends by running `doctor` (tool presence) and `enforce` (development-policy
compliance) automatically and printing both results — read the enforce summary if it
reports `NON-COMPLIANT`. On Windows, running with `-NoWSL` intentionally skips the WSL
engineering plane, so `enforce` will correctly report non-compliance until WSL is set up.

Bootstrap installs the Dev Container CLI (`devcontainer`) on every platform so
`policy/development.json`'s `requireDevContainer` project check passes without an extra
step.

On WSL, `wsl/bootstrap.sh` also generates a company SSH key (`~/.ssh/id_ed25519_company`)
and prompts once for your git identity (name/email) if not already set — idempotent,
safe to re-run. **A key working on one Git host does not mean it's registered on
another** — add the printed public key separately to each host you use (GitHub, Azure
DevOps, etc.) under that host's own SSH-keys settings. See `wsl/configure-git.sh`.
