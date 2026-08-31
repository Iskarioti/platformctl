# Development Environment Enforcement

## Goal

Bootstrap creates the workstation. Enforcement keeps it compliant and makes new
projects deterministic.

## Workstation compliance

```text
workstation enforce
workstation enforce --repair
```

`--repair` is intentionally limited. It may create missing approved `~/src` project
roots; it does not disable security controls, uninstall software, alter corporate
networking, or silently rewrite application repositories.

## Approved project roots

```text
~/src/company
~/src/platform
~/src/automation
~/src/labs
~/src/tooling
```

On Windows, these paths are inside WSL/Linux. Do not develop application projects
under `/mnt/c`, OneDrive, Downloads, Desktop, or Documents.

## Project lifecycle

```text
workstation project templates
workstation project init fastapi-service hub-notifications --area company
workstation project adopt ~/src/company/already-cloned-repo
workstation project check
workstation project doctor
workstation project open
```

`adopt`/`check`/`doctor`/`open` all take either a real path or a bare project name
(e.g. `workstation project open wiocchub-api`), resolved by searching
`policy/development.json`'s `projectRoots` (`scripts/posix/resolve-project.sh`) — a
name that matches nothing, as a path or under any configured root, is a hard error
listing the configured roots, never a silent fallback to `$PWD`. That silent fallback
was a real bug: running a bare project name from the wrong directory used to check
whatever directory you happened to be in instead (once even flagging unrelated
`Dockerfile.template` files under `~/.vscode-server/extensions/` as if they belonged
to the named project), rather than failing loudly.

`init` scaffolds a brand-new project from a template. `adopt` is for a project that
already exists — pre-existing, or freshly `git clone`d — and registers it by writing
`.platformctl/project.json` only; it never touches any other file, never runs
`git init`, never stages or commits anything. A pre-existing/cloned codebase keeps its
own structure and conventions, managed independently — `adopt` does not force it to
match a template's scaffolding. Without adopting it, a cloned project has no
`.platformctl/project.json` and is invisible to `project check`'s compliance model and
the dashboard's governed-projects panel alike — it still shows up there now (flagged as
untracked), but closing that gap for real means running `adopt`.

`open` runs `check` informationally (a non-compliant project still opens, just
flagged), then, if `.devcontainer/devcontainer.json` exists, builds/starts the Dev
Container and attaches VS Code to it directly — not just a plain `code .` open. Falls
back to a plain open if the Dev Container CLI isn't installed
(`scripts/posix/install-devcontainers-cli.sh`, wired into every platform's bootstrap)
or the container fails to build.

## Project contract

Governed projects require Git, a Dev Container, `.editorconfig`, `.gitignore`,
`README.md`, `.env.example`, `.platformctl/project.json`, a non-root Dev Container
user, no tracked `.env` secrets, no private-key-like tracked filenames, and no Docker
`:latest` base image.

A CI workflow is also required, but which file depends on the project's `origin`
remote: `.github/workflows/ci.yml` + `.github/workflows/policy.yml` for GitHub-hosted
projects, `azure-pipelines.yml` for Azure DevOps-hosted ones (`.github/workflows/*`
never executes there) — detected automatically, not configured.

`devcontainer.json` validity is checked with the Dev Container CLI's own parser when
it's installed, not plain `jq empty` — `jq` rejects the JSONC comments/trailing commas
the Dev Container spec legitimately allows (a real project's devcontainer.json using
`//` comments always failed this check silently until it did). Falls back to plain
`jq` when the CLI isn't installed, which is fine for every platformctl template (none
use comments).

Lockfiles begin as a warning in v3.1 so a freshly generated project can install its
dependencies first. Change `projects.lockfilePolicy` to `required` once every active
template generates lockfiles during initialization.

## Git SSH access inside Dev Containers

Every governed devcontainer.json (this repo's own templates, plus adopted projects
like `wiocchub-api`/`wiocchub-app`) forwards SSH access into the container via an
agent socket, never by mounting a private key file directly:

```json
"mounts": ["source=${localEnv:HOME}/.ssh/agent.sock,target=/ssh-agent,type=bind"],
"containerEnv": {"SSH_AUTH_SOCK": "/ssh-agent"}
```

`scripts/posix/ensure-ssh-agent.sh` keeps a persistent `ssh-agent` listening at that
fixed socket path (`~/.ssh/agent.sock`, not the default random `/tmp/ssh-*/agent.<pid>`
path, which a static devcontainer.json mount can't reference) and loads only
company-purposed identities into it (see the script's own comments for exactly which
key basenames and why). A container can ask the agent to sign a challenge but can
never read key material back out through the socket — a compromised container
(malicious dependency, container escape) cannot exfiltrate the key for reuse
elsewhere, unlike a direct key-file mount. It also means only the identities you
`ssh-add` are ever exposed to a container, never every key sitting in `~/.ssh`
(personal keys included) the way mounting the whole directory would.

The script runs from `project-open.sh` before every `devcontainer up` (so it works
regardless of shell history) and from `architect.bashrc`/`architect.zshrc` (so a new
terminal always has it too). Add a new project template's own SSH mount by copying
the two lines above into its devcontainer.json.

## Git identity inside Dev Containers

Unlike SSH keys, `.gitconfig` (just `user.name`/`user.email`, not a secret) IS mounted
directly, read-only, into every governed devcontainer.json:

```json
"source=${localEnv:HOME}/.gitconfig,target=/home/<remoteUser>/.gitconfig,type=bind,readonly"
```

VS Code's Dev Containers extension has a client-side setting for this
(`dev.containers.copyGitConfig`, default on) that's supposed to make an explicit mount
unnecessary — checked and rejected: verified against a real container attached through
this repo's own `project-open.sh` flow (`devcontainer up` via the CLI, then `code
--folder-uri` to attach) that no `.gitconfig` ever appears inside the container this
way, even minutes after a confirmed-connected attach. Whether that's because the
setting only fires when VS Code itself creates the container, or needs an interactive
terminal opened first, wasn't chased further — the direct mount is the one confirmed
to actually work in this repo's flow, so that's what every template uses. Read-only
so a container process can't write back and mutate the host's real `.gitconfig`
(check before adding a `postCreateCommand` that runs `git config --global ...` inside
a container using this mount — it would fail against a read-only file, unlike
`wiocchub-api`'s own devcontainer.json, which predates this and still mounts
`.gitconfig` read-write for exactly that reason).

## GitHub enforcement

Important repositories should protect `main` with pull requests, blocked force pushes,
required CI checks, and appropriate secret/dependency scanning. Local hooks can be
bypassed and are not authoritative.

## platformctl autosync boundary

The one-minute autosync belongs only to the workstation repository. Do not copy its
auto-commit/auto-push mechanism into product/application repositories.
