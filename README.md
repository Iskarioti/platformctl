# Systems & Platform Architect Workstation

A GitHub-first, fully automated, adaptive workstation for Windows, Linux and macOS,
with policy-as-code enforcement for development environments.

The repository is the source of truth. After bootstrap:

- workstation configuration is governed by `workstation.json`;
- development behavior is governed by `policy/development.json`;
- project runtimes live in Dev Containers;
- GitHub CI/rules remain the authoritative merge boundary.


## New machine

### Windows

```powershell
git clone <repo-url>
cd platformctl
.\bootstrap.ps1
```

### Linux / macOS

```bash
git clone <repo-url>
cd platformctl
./bootstrap
```

**New here? Read [`docs/getting-started.md`](docs/getting-started.md) next** -
the one narrated path from a fresh clone to shipping real work, across every
persona this workstation serves (PhD/CS researcher, AI Engineer, DevSecOps
engineer, Platform Engineer, Systems Engineer). Everything below is quick
reference; that doc is the walkthrough.

## Core commands

```text
# Workstation health
workstation validate
workstation apply
workstation doctor                        # real cross-domain status - security/capacity/drift/labs/templates
workstation enforce [--repair]
workstation drift-check                   # running dev-services vs. development/catalog.json
workstation rename-device [-WhatIf]       # enforce LAP-<serial>/DSK-<serial> naming, idempotent

# Start a project
workstation project templates
workstation project init fastapi-service my-api --area company
workstation project adopt ~/src/company/already-cloned-repo
workstation project check | doctor | open

# Local infrastructure
workstation services up core              # Postgres + Redis (see: services list)
workstation services up redis kafka
workstation services scaffold <name>      # new dev-service file skeleton, pre-wired to consumes
workstation services rotate <service>     # regenerate + apply a secret (redis/qdrant/minio/open-webui)
workstation models up                     # shared local Ollama runtime
workstation models pull gemma3:4b
workstation lab list                      # pre-production architecture validation
workstation lab up redis-cluster --runtime docker

# Quality & security
workstation security scan .               # Semgrep/Gitleaks/TruffleHog/Trivy/Checkov
workstation security sbom .                # CycloneDX SBOM via Syft
workstation research doctor               # LaTeX/Pandoc/Quarto/pixi toolchain check
workstation catalog stats                 # which templates/services actually get used
workstation catalog costs                 # illustrative cloud-cost sizing for what's running now

# Editor / shell
workstation editor list
workstation editor profile <platform|nvchad|minimal|personal>

# Automation & maintenance
workstation sync
workstation update
workstation autosync enable | pause [minutes] | resume
workstation upgrade
workstation autoupgrade enable
workstation dashboard | dashboard enable
workstation backup
workstation restore <backup-file>
workstation dr-drill                      # rehearse backup+restore into a throwaway dir
workstation changelog
```

## Development model

```text
Windows host
  -> WSL2 Ubuntu engineering plane
     -> ~/src/company|platform|automation|labs|tooling
        -> approved project template
           -> VS Code Dev Container
              -> project runtime/toolchain
                 -> local checks
                    -> GitHub CI
                       -> protected PR
```

Project repositories should not live under `/mnt/c`, OneDrive, Desktop, Downloads, or
other Windows-mounted paths when developing on Windows.

`platformctl` autosync only manages this workstation repository. It never auto-commits
or auto-pushes application repositories.

## Approved project templates

| Template | Use it for |
|---|---|
| `fastapi-service` | a general-purpose Python/FastAPI service |
| `python-service` | a general-purpose Python service, no web framework assumed |
| `react-app` | a React/Vite frontend |
| `terraform` | Terraform-only infrastructure |
| `infra` | Terraform **+ Ansible** together, plus Azure CLI/kubectl/helm - broader than `terraform` |
| `network-automation` | Netmiko/Nornir/NAPALM/Scrapli network-device automation |
| `ai` | classical ML/data-science (FastAPI, numpy, pandas, scikit-learn) - **not** LLM-specific |
| `rag-app` | a retrieval-augmented-generation service (Qdrant + local model runtime) |
| `agent-app` | a LangGraph-based agentic service |
| `mcp-server` | a Model Context Protocol server |
| `research-python` | Python/JupyterLab research and analysis |
| `research-paper` | a LaTeX/Quarto paper - **not** a code project |

`workstation project templates` prints this same list with descriptions at
the terminal. Create one with:

```bash
workstation project init <template> <name> --area company|platform|automation|labs|tooling
```

12 templates, several deliberately overlapping (`fastapi-service`/
`python-service`, `terraform`/`infra`) works fine for discoverability at this
size - the Platform Engineer role review flagged this as an early risk, not
a current problem, and it doesn't have a concrete fix yet because there
isn't one worth building preemptively. `workstation catalog stats` (real
usage data, not a guess) is the signal to watch before it becomes one -
consolidate or archive whichever of a template's own uses actually decays,
using `templates/catalog.json`'s `status: deprecated` field, once that data
says so.

## Security model

The setup never weakens App Control, WDAC, ConstrainedLanguage, execution policy,
Secure Boot, endpoint controls, or installer verification.

Project policy forbids tracked secret files/private keys, Docker `:latest` base
images, root Dev Container users, and Windows-filesystem development when WSL is the
required engineering plane.

## Documentation

**Start here:** [`docs/getting-started.md`](docs/getting-started.md).

By subsystem:

- `docs/development-services-v2.md` - shared Docker dev-service catalog
- `docs/labs.md` - pre-production architecture validation
- `docs/security-scanning.md` - DevSecOps toolchain (`workstation security`)
- `docs/research-computing.md` - research toolchain (`workstation research`)
- `docs/ai-workstation.md` - the full AI/ML lifecycle
- `docs/editors.md` - Neovim/Vim profile system
- `docs/shell-experience.md` - prompt/shell/terminal configuration
- `docs/desktop-appearance.md` - Dock/Taskbar/wallpaper
- `docs/fonts.md` / `docs/keybindings.md` / `docs/windows-terminal.md` / `docs/powershell-profile.md`

Automation and reliability:

- `docs/autosync.md` / `docs/auto-update.md`
- `docs/development-enforcement.md`
- `docs/control-plane.md` / `docs/reliability.md`
- `docs/capacity-planning.md` / `docs/secrets-rotation.md` / `docs/dependency-updates.md`
- `docs/compliance-evidence-mapping.md`
- `docs/new-machine.md`

Reference / background:

- `docs/architecture.md`
- `docs/adr/` - architecture decision records
- `docs/ai-agent-maintenance.md`
