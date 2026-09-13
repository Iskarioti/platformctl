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

## Device naming

Every machine this repo provisions should be named `LAP-<BIOS_SERIAL>` (laptop)
or `DSK-<BIOS_SERIAL>` (desktop) - a fixed, deterministic convention based on
real hardware identity, not a hostname anyone has to remember or pick.

```text
workstation rename-device            # check, and rename if it doesn't match
workstation rename-device -WhatIf    # (Windows) report what would happen, change nothing
workstation rename-device --what-if  # (macOS/Linux) same, POSIX flag spelling
```

Idempotent and safe to run any time, not just at provisioning: it reads the
BIOS/hardware serial number and chassis type, computes the target name, compares
it to the current one, and only acts on a real mismatch - a machine already
named correctly gets a clean "nothing to do," not a no-op rename.

- **Device kind** is detected from the DMTF chassis-type code (the same
  numbering Windows, Linux, and SMBIOS all use), falling back to
  `PCSystemType`/battery presence on Windows or a `MacBook*` model-name check
  on macOS for anything the chassis-type list doesn't cleanly cover.
- **A missing or generic-placeholder serial number** (`"0"`, `"To Be Filled By
  O.E.M."`, an empty string, etc. - common on VMs and some consumer hardware
  that never had a real serial programmed) makes the script refuse outright
  rather than build a name from garbage input.
- **Windows computer names are capped at 15 characters** (the NetBIOS limit) -
  a serial number long enough to exceed that gets truncated to fit, with a
  warning, rather than let `Rename-Computer` silently truncate or reject it.
  macOS/Linux hostnames have far more headroom (63/64 characters) so this
  rarely matters there.
- **Never restarts automatically.** A rename needs a restart (Windows) or at
  least a re-login (macOS/Linux) to take full effect everywhere, but that's
  disruptive enough to want an explicit opt-in: pass `-Restart`/`--restart`,
  or restart manually when convenient.
- **Not run under WSL** - WSL2's DMI data reflects the lightweight Hyper-V VM
  it runs in, not the physical laptop/desktop's real BIOS serial, and WSL
  itself isn't a separate device to name. Rename the Windows host instead
  (`workstation rename-device` from Windows PowerShell); WSL's own copy of the
  command detects it's running under WSL and skips with an explanation rather
  than computing a name from the VM's fake identity.
- **macOS sets all three of Apple's separate name concepts** together
  (`ComputerName`, `HostName`, `LocalHostName` via `scutil --set`) so they
  don't drift apart from each other.
- Live-verified on this machine's actual hardware (a real HP laptop):
  correctly detected as `laptop` (chassis type 10, battery present), BIOS
  serial `5CD5354RZ5`, and - since the machine was already named
  `LAP-5CD5354RZ5` - correctly reported "already matches, nothing to do."
  The mismatch/truncation/generic-serial code paths were each verified with
  controlled test inputs (not a real rename) before shipping. **Not tested
  on real macOS or non-WSL Linux hardware** - no such machine available this
  session; the logic mirrors the Windows script closely but hasn't been run
  for real there.

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

Bootstrap (WSL/Linux and macOS) also installs a DevSecOps toolchain (Semgrep,
Gitleaks, TruffleHog, Trivy, Grype, Syft, Checkov, Cosign, Conftest - see
`docs/security-scanning.md`) and a research-computing toolchain (TeX Live/
Pandoc/Quarto/pixi - see `docs/research-computing.md`), plus Alacritty and a
managed tmux/ripgrep config (`docs/shell-experience.md`). Verify all of it in
one place with `workstation doctor`, or per-domain with `workstation
security doctor` / `workstation research doctor`.

On WSL, `wsl/bootstrap.sh` also generates a company SSH key (`~/.ssh/id_ed25519_company`)
and prompts once for your git identity (name/email) if not already set — idempotent,
safe to re-run. **A key working on one Git host does not mean it's registered on
another** — add the printed public key separately to each host you use (GitHub, Azure
DevOps, etc.) under that host's own SSH-keys settings. See `wsl/configure-git.sh`.

**If you already have working SSH keys on the Windows side** (registered with your Git
hosts there), prefer reusing them over generating fresh WSL-only ones — one less key to
register per host:

```bash
wsl/import-windows-ssh-keys.sh
```

Copies every private/public key pair from the Windows profile's `~/.ssh` into WSL's
native filesystem (never referenced in place on `/mnt/c` — OpenSSH refuses a private
key with NTFS-loose permissions) with correct `600`/`644` permissions. Windows stays
canonical; re-run after adding a new key there. It does not guess which key belongs to
which host — add/update the matching `Host` blocks in `~/.ssh/config` yourself (or ask
an agent to, given the running `ssh -T git@<host>` output). Deliberately not wired into
bootstrap — importing arbitrary existing keys is a bigger action than generating a
fresh one, and the same directory may hold keys for unrelated purposes.

**Kept in sync automatically** via the existing autosync cycle (`docs/autosync.md`):
every autosync run also re-runs this import (WSL-only; a no-op on native Linux/macOS)
before its git-sync logic, so a new Windows key gets copied into WSL within a minute of
being added, with no manual step. This is **pure local file copying** — autosync's
git-commit path is completely unmodified and still refuses to stage anything
secret-bearing; keys are never touched by, or go anywhere near, git.
