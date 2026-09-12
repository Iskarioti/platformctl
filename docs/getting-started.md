# Getting Started

**Read this first.** Everything else under `docs/` is reference material for a
specific subsystem - this page is the one narrated path from "just cloned the
repo" to "shipping real work," across every persona this workstation serves
(PhD/CS researcher, AI Engineer, DevSecOps engineer, Platform Engineer,
Systems Engineer). If you only read one doc, read this one.

## 1. First machine setup

Windows (PowerShell):
```powershell
git clone <repo-url>
cd platformctl
.\bootstrap.ps1
```

Linux or macOS:
```bash
git clone <repo-url>
cd platformctl
./bootstrap
```

This installs everything: fonts, shell/prompt, editor profiles, the DevSecOps
toolchain, the research-computing toolchain, Docker, WSL (Windows only), and
the `workstation` command itself. It ends by running `doctor` and `enforce`
automatically - if `enforce` reports `NON-COMPLIANT`, read its summary before
doing anything else.

## 2. Every normal morning

```bash
wsl                  # Windows only - everything below runs inside WSL/Linux/macOS
platformctl doctor   # separate diagnostics CLI (net/tls/docker/incident tooling)
workstation doctor   # this repo's own tool-presence + background-automation check
```

Don't start any dev-services, models, or labs until you actually need them -
none of them auto-start after bootstrap.

## 3. Pick what you're doing today

| I want to... | Type this |
|---|---|
| Start a new project | `workstation project templates` (see the table below), then `workstation project init <template> <name> --area <area>` |
| Stand up Postgres/Redis/Kafka/etc. for local dev | `workstation services up core` (or `redis`, `kafka`, `messaging`, `all`, ... - `workstation services list`) |
| Run a local LLM | `workstation models up` then `workstation models pull gemma3:4b` |
| Validate an architecture before production (Kubernetes, Redis Cluster, RAG pipeline, agent mesh, ...) | `workstation lab list`, then `workstation lab up <name>` |
| Run a security scan (SAST/secrets/vulns/IaC) | `workstation security scan .` (or `workstation security doctor` to check the toolchain first) |
| Write a LaTeX/Quarto paper | `workstation project init research-paper my-thesis --area labs` |
| Do Python/notebook research | `workstation project init research-python my-analysis --area labs` |
| See what's running, with health status | `workstation dashboard` (or `workstation dashboard enable` for an always-on background service) |
| Switch Neovim/editor style | `workstation editor list` / `workstation editor profile <name>` |

## 4. Which project template?

`workstation project templates` lists all of these with a one-line
description; the table below is the same information for quick reference
when you're not sure which of several similar-sounding ones you want.

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

## 5. Doing the work (inside a Dev Container)

```bash
cd ~/src/<area>/<project>
git fetch --all --prune && git switch main && git pull --ff-only
git switch -c feature/<ticket>-<description>
code .                      # reopen in Dev Container when prompted
```

Every template's own README documents its exact lint/test commands (e.g.
`ruff check .` + `pytest -q` for Python ones, `terraform validate` for
Terraform, `make paper` for `research-paper`) - there's no single universal
"task verify" across templates, each one is self-contained and documents
itself.

Before pushing, run a security scan if the change touches anything
security-sensitive:
```bash
workstation security scan .
```

Push from WSL, not from inside the Dev Container, unless you've deliberately
forwarded Git credentials into it:
```bash
exit
git push -u origin HEAD
```

## 6. Heavier local model work

Switch the WSL resource profile before a large model:
```powershell
.\windows\25-set-wsl-profile.ps1 -Profile ai-lab   # Windows PowerShell, not WSL
```
```bash
workstation models up
workstation models pull gemma3:12b
```
Return to the default profile afterward the same way (`-Profile default`).
Native-Windows NPU/OpenVINO benchmarking is separate: `.\windows\50-npu-lab.ps1`.

## 7. Incident / diagnostics work

Always from WSL directly, never from inside a project's Dev Container:
```bash
platformctl net diagnose <host> --port <port>
platformctl incident collect --host <host> --port <port>
```

## 8. End of a work session

```bash
git status && git push        # from WSL
docker system df              # check Docker disk usage periodically
workstation services down     # stop dev-services you started (keeps data)
workstation lab destroy <name> --runtime <docker|kubernetes> --yes   # if you ran a lab
```

## Where to go deeper

- `docs/development-services-v2.md` - the full dev-service catalog
- `docs/labs.md` - pre-production architecture validation
- `docs/security-scanning.md` - the DevSecOps toolchain in detail
- `docs/research-computing.md` - the research-computing toolchain in detail
- `docs/ai-workstation.md` - the full AI/ML lifecycle
- `docs/editors.md` / `docs/shell-experience.md` / `docs/desktop-appearance.md` - environment/appearance
- `docs/architecture.md` - why this repo is built the way it is
