# Changelog

## 3.9.2

Added `workstation autosync pause [minutes]` / `resume`: autosync fires every 5
minutes and commits/pushes whatever is dirty at that moment (by design, so work
is never silently lost across machines - see `docs/autosync.md`'s "AI agents"
section), which can interleave an autosync commit into the middle of a
multi-step agent task. Prompted by exactly that happening twice in the previous
AI-workstation work (`e52a1fd`, `6c8bcf6` - the latter caught this very fix's
own in-progress edits mid-task).

- `pause` writes `.state/autosync.pause` (an ISO-8601 UTC expiry, default 30
  min); both `scripts/common/autosync.sh` and `autosync.ps1` skip the git-sync
  step entirely while it's unexpired, and self-heal a stale/forgotten pause
  file by deleting it and proceeding normally on the very next cycle - it can
  never disable autosync indefinitely.
- Wired into `workstation autosync pause|resume` (POSIX and
  `scripts/common/autosync-control.ps1`).
- New AGENTS.md rule 14: pause before a task that edits several already-tracked
  files across more than one tool call, resume once committed or abandoned.
- Also fixed `docs/autosync.md` still documenting the pre-3.8.5 "once per
  minute" interval everywhere; it's been every 5 minutes since that fix.

## 3.9.1

Added the "prompt engineering interface" piece from Andrew's target AI
architecture diagram (`IMG_4954.PNG`): a new `open-webui` dev-service
(`ghcr.io/open-webui/open-webui:v0.11.3`), same 7-file pattern as `qdrant`,
joining `platform-dev` to reach the shared `ollama` runtime by name. Its
`WEBUI_SECRET_KEY` is a generated secret (same `generate_secret_file` mechanism
as every other service's credential). Added to the `ai` profile in both
`development/catalog.json` and `policy/development.json`, plus a dashboard tile.

Verified live: builds and passes its health check, serves `http://127.0.0.1:8081`
(HTTP 200), and its `/ollama/api/*` routes correctly reach the configured
`OLLAMA_BASE_URL` (confirmed via a `401 Not Authenticated` rather than a
connection error - full chat verification needs a logged-in browser session,
which is expected: the first account created becomes the local admin). Its
first-boot Hugging Face embedding-model download is resumable across restarts
via its own data volume once it completes once.

## 3.9.0

Holistic AI/ML workstation: local model testing, an MCP server dev/test/deploy
lifecycle, and RAG/agentic ("AgentOS") architecture validation before production —
following the repo's existing dev-service/project-template/lab three-tier mechanism
rather than inventing a new one. See `docs/ai-workstation.md`.

- **`ai-runtime` fixed and wired into `workstation`.** Its `compose.yaml` pinned
  `OLLAMA_VERSION:-latest` — a live violation of this repo's own `forbidLatestTag`
  policy enforced everywhere else — now pinned via `ai-runtime/versions.env`. Its
  `ollama` service now also joins `platform-dev` (Compose services can belong to
  multiple networks at once), so any project already joined there reaches
  `ollama:11434` with zero extra wiring. New `workstation models
  up|down|status|pull|list|run`, wired via `scripts/posix/models.sh` /
  `scripts/common/models.ps1` — previously Taskfile-only and outside the CLI
  entirely (`ai-runtime/Taskfile.yml` removed).
- **New `qdrant` dev-service** (`development/catalog.json`, `policy/development.json`
  `ai` profile) — the same 7-file pattern as every other service. Its API key is a
  real generated secret (`generate_secret_file`, same mechanism as Redis).
- **Three new project templates**: `mcp-server` (Python, official `mcp` SDK, Node
  feature for the MCP Inspector), `rag-app` (FastAPI + LangChain + Qdrant + Ollama),
  `agent-app` (FastAPI + LangGraph + Ollama). Verified by actually building each
  template's Dev Container and exercising it live — not just `pytest` — per this
  repo's standing "never trust an unverified 'should work'" discipline: `rag-app`'s
  `/ingest`+`/query` round-tripped a real fact through Qdrant + `nomic-embed-text` +
  `gemma3:4b`; `agent-app`'s LangGraph `/invoke` got a real `gemma3:4b` response;
  `mcp-server`'s scaffolded tool was listed and called successfully via the real MCP
  Inspector CLI. Found and fixed two real bugs this way: `rag-app`'s and
  `agent-app`'s `requirements.txt` used open version ranges that resolve fine on the
  WSL host's Python 3.12 but hit a genuine pip `ResolutionImpossible` inside the Dev
  Container's actual Python 3.13 — now pinned to exact, mutually-compatible
  versions; and `rag-app`'s `app/main.py` never called `load_dotenv()` despite
  depending on `python-dotenv` and despite `.env.example` documenting that
  `QDRANT_API_KEY` must be loaded from `.env`.
- **Two new labs**: `labs/ai/rag-pipeline` (disposable Ollama+Qdrant; `smoke` and
  `qdrant-outage` tests) and `labs/ai/agent-mesh` (three-replica LangGraph mesh
  behind Ollama; `smoke` and `node-failure` tests), both Docker- and
  Kubernetes-runtime manifests following `redis-cluster`'s established layout.
  Docker runtime verified end-to-end for both (real retrieval scores, real
  independent per-replica model output, real outage/node-failure recovery);
  Kubernetes runtime not live-verified this round (needs `workstation lab
  toolchain install` first).
- **Found and fixed a real, pre-existing gap while verifying Phase D**: `labs.sh`
  has always existed, fully implemented, but `lab` was never wired into
  `workstation.sh`'s command dispatch, `setup`'s command allow-list, or
  `setup.ps1` — `workstation lab ...` had likely never worked at all before this.

## 3.8.5

- Fixed the Windows autosync scheduled task flashing a visible PowerShell console
  window every single run (every 1 minute) — reported live by Andrew. Task
  Scheduler's own "Hidden" task setting only hides a task from the Task Scheduler
  UI; it does not suppress the console window a launched `pwsh.exe` allocates. New
  `scripts/windows/run-hidden.vbs` routes the real command through `wscript.exe`
  (a GUI-subsystem host that never shows a window itself) + `Shell.Run` with a
  hidden window style, applied to both `install-autosync.ps1` and
  `install-autoupgrade.ps1` (same bug, just far less noticeable at once/day).
- `scripts/windows/install-autosync.ps1` also switched from raw `schtasks.exe` to
  the `ScheduledTasks` PowerShell module (matching `install-autoupgrade.ps1`'s
  existing style): `schtasks.exe`'s `/TR` value has a hard, largely undocumented
  261-character limit, and this repo's own path (nested under a synced "OneDrive -
  WIOCC\Documents" folder) plus the hidden-runner wrapper routinely exceeds it.
  Eased the interval from every 1 minute to every 5 minutes while at it, matching
  the WSL/macOS-side interval change already made in 3.8.3's autosync work.
- Found along the way: re-registering an *already-existing* scheduled task via
  `Register-ScheduledTask -Force` can fail with `Access is denied` from a
  non-elevated session, even though the task itself runs unelevated as a normal
  user — Andrew had to run the install script himself in an elevated PowerShell.
  Verified end-to-end afterward via `Get-ScheduledTaskInfo`: two consecutive runs
  exactly 5 minutes apart, both `LastTaskResult: 0`, zero missed runs.

## 3.8.4

- Found and fixed the last real blocker in the `workstation project open wiocchub-api`
  bug chain (path resolution → JSONC validation → WSL networking, all fixed in
  3.8.2/3.8.3): `wiocchub-api`'s own `postCreateCommand.configure-git` step ran
  `git config --global --add safe.directory ...`, which failed with `error: could not
  write config file /home/vscode/.gitconfig: Device or resource busy`. Git's config
  writer works by atomically renaming a temp file over the target, and you cannot
  rename over a bind-mounted file's mountpoint from inside a container — an
  incompatibility with the `.gitconfig` file mount added in 3.8.1, independent of
  read-only vs. read-write. Fixed (in `wiocchub-api`'s own devcontainer.json, not
  tracked in this repo) by switching to `sudo git config --system --add safe.directory
  ...`, which writes to `/etc/gitconfig` — a plain container-local file, never
  bind-mounted — achieving the same effect. Verified end-to-end: the container now
  builds and starts cleanly, `install-poetry`/`install-claude`/`install-dev-tools`/
  `configure-git` all succeed.
- Found along the way (not fixed, just documented — this is a characteristic of
  `wiocchub-api`'s own devcontainer.json, not something to silently change): its
  `runArgs` hardcodes a fixed `--name=wiocchub-api`. `project-open.sh`'s own
  `devcontainer up` invocation (run from inside WSL) and VS Code's native "Reopen in
  Container" flow label the resulting container's `devcontainer.local_folder` with
  different path formats for the exact same project (a plain WSL path vs. a Windows
  UNC `\\wsl.localhost\...` path) — so neither recognizes the other's container as
  "already existing," and running both concurrently against the same project races on
  that fixed container name, with one attempt failing with a Docker `Conflict: name
  already in use` error. Don't run `project open` and VS Code's own native reopen at
  the same time against a project with a hardcoded container name.

## 3.8.3

- Switched WSL's networking mode from `mirrored` to `nat` in all three managed
  configs (`wsl/.wslconfig`, `wsl/profiles/default.wslconfig`,
  `wsl/profiles/ai-lab.wslconfig`) — root-caused a real, live networking outage
  (WSL couldn't even reach its own default gateway, while the Windows host had
  full connectivity to the same address) to a conflict between mirrored mode's
  DNS tunneling and this machine's Global Secure Access Client (Microsoft Entra
  Zero Trust). WSL's own warning ("DNS Tunneling is disabled" when GSA is
  detected) implied this was already handled, but the actually-deployed
  `.wslconfig` still had `dnsTunneling=true` — the repo's own file had been
  edited to `false` at some point but never redeployed, so the fix never took
  effect. Switching to NAT removes the conflict entirely (NAT doesn't use DNS
  tunneling or mirrored mode's firewall integration at all, so both settings
  are dropped rather than left as dead config). Verified end-to-end after
  redeploying via `windows/25-set-wsl-profile.ps1 -Profile default` +
  `wsl --shutdown`: DNS resolution, gateway ping, and the exact
  `redis/redis-stack-server:7.4.0-v8` pull that had been failing all work now.

## 3.8.2

- Fixed a real bug reported live: `workstation project open wiocchub-api` (run from
  `$HOME`, not the project itself) silently checked `$HOME` instead — `cd
  "wiocchub-api"` failed (no such relative path), the failed command substitution
  returned empty, and `"${1:-$PWD}"` treated that empty string as "unset" and quietly
  defaulted to `$PWD`, reporting 11 unrelated failures (including flagging
  `Dockerfile.template` files under `~/.vscode-server/extensions/` as if they were the
  named project's).
- New `scripts/posix/resolve-project.sh` (shared by `project-open.sh`,
  `project-check.sh`, `project-doctor.sh`, `project-adopt.sh`): a bare project name is
  now resolved by searching `policy/development.json`'s `projectRoots`
  (`~/src/company`, `~/src/platform`, etc.) — `workstation project open wiocchub-api`
  now works from anywhere. A name that resolves nowhere is a hard error listing the
  configured roots, never a silent fallback.
- Fixed `project-check.sh` validating `devcontainer.json` with plain `jq empty`, which
  rejects the JSONC comments/trailing commas the Dev Container spec legitimately
  allows — surfaced immediately once the resolve fix above let `project check` reach
  `wiocchub-api`'s real devcontainer.json (which uses `//` comments) for the first
  time. Now uses the Dev Container CLI's own parser when installed, falling back to
  plain `jq` (fine for every platformctl template, none of which use comments).

## 3.8.1

- Investigated whether VS Code's Dev Containers `dev.containers.copyGitConfig` setting
  (client-side, on by default) could replace the direct `.gitconfig` bind mount that
  `wiocchub-api`'s devcontainer.json already had — verified against a real container
  attached through this repo's own `project-open.sh` flow (`devcontainer up` via the
  CLI, then `code --folder-uri` to attach) that it does **not** fire: no `.gitconfig`
  ever appeared inside the container, even minutes after a confirmed-connected
  attach. Kept the direct mount rather than removing it on an unverified assumption.
- Added that same `.gitconfig` mount (read-only, unlike SSH keys this isn't a secret
  so a direct mount is fine — but read-only so a container process can't write back
  and mutate the host's real file) to all 8 platformctl project templates and to
  `wiocchub-app` (neither had one before, so `git commit` inside their Dev Containers
  previously had no identity at all). `wiocchub-api` already had one — read-write,
  since its `postCreateCommand` writes `git config --global --add safe.directory`
  through it — left as-is, not read-only.

## 3.8.0

- Every governed Dev Container (this repo's 8 project templates, plus the adopted
  `wiocchub-api`/`wiocchub-app` projects) now forwards Git SSH access via an
  `ssh-agent` socket instead of mounting private key files directly:
  `"mounts": ["source=${localEnv:HOME}/.ssh/agent.sock,target=/ssh-agent,type=bind"]`
  + `"containerEnv": {"SSH_AUTH_SOCK": "/ssh-agent"}`. A container can ask the agent
  to sign a challenge but can never read key material back out through the socket,
  so a compromised container (malicious dependency, container escape) can't
  exfiltrate a key for reuse elsewhere — and only the identities actually loaded into
  the agent are ever exposed, not every key sitting in `~/.ssh` (personal keys
  included) the way mounting the whole directory would.
- New `scripts/posix/ensure-ssh-agent.sh` keeps a persistent agent listening at a
  FIXED socket path (`~/.ssh/agent.sock` — the default `ssh-agent` picks a new random
  path every start, which a static devcontainer.json mount can't reference) and loads
  only company-purposed identities into it (`id_ed25519_company`, `id_rsa` — the two
  keys `~/.ssh/config`'s Host blocks map to company git hosts; never a personal key).
  Runs from `project-open.sh` before every `devcontainer up` (works regardless of
  shell history) and from `architect.bashrc`/`architect.zshrc` (so a new terminal
  always has it too).
- Verified end-to-end against a real container: `ssh-add -l` inside the container
  showed both forwarded identities, `SSH_AUTH_SOCK=/ssh-agent` was set correctly, and
  `ssh -T git@github.com` run *inside the container* authenticated successfully
  through the forwarded agent — no private key file ever present in the container.

## 3.7.3

- Fixed `workstation project open` (`scripts/posix/project-open.sh`) not actually
  building/starting or attaching VS Code to a project's Dev Container — it previously
  just ran a bare `code .`, and (under `set -e`) would abort entirely before even doing
  that if the project happened to be policy-non-compliant. Now: `project-check.sh`
  runs informationally (never blocks opening), and if `.devcontainer/devcontainer.json`
  exists, it builds/starts the container via `devcontainer up` and attaches VS Code to
  it directly (`code --folder-uri vscode-remote://dev-container+<hex>/...`), falling
  back to a plain `code .` open if the Dev Container CLI isn't installed or the build
  fails.
- Found and fixed two real, verified-on-hardware bugs along the way:
  - The Dev Container CLI was never actually wired into WSL bootstrap
    (`wsl/install-devcontainers-cli.sh` was an orphaned script, never called).
    `scripts/posix/install-devcontainers-cli.sh` now installs it via mise-managed Node
    and is called from `wsl/bootstrap.sh` (and the Linux/macOS bootstraps, which already
    called it). It symlinks the real binary into `~/.local/bin/devcontainer` rather than
    trusting bare `devcontainer`/`node` PATH resolution — on this WSL machine, that bare
    name resolves to an unrelated Windows-native `@devcontainers/cli` install (via WSL's
    Windows-PATH interop) that can never see Docker, and even a fully non-interactive
    `bash` invocation has neither `~/.local/bin` nor mise's shims on PATH at all (only
    `~/.bashrc`/`~/.profile` add them, neither sourced there) — `project-open.sh`
    explicitly prepends mise's shims dir and calls the installed binary by absolute path
    to sidestep both.
  - The `vscode-remote://dev-container+<hex>/...` URI's authority is hex-encoded JSON
    (`{hostPath, localDocker, configFile}`), not a hex-encoded path as first assumed —
    confirmed by decoding a live "could not be established" message from `code --status`
    for an actual in-progress attach. The wrong (path-only) encoding still opened *a*
    window, which read as success until checked with `code --status` and given time to
    settle — it was not genuinely attached. The corrected encoding was verified stable
    (a `[Dev Container: ...]` window that persisted with no connection error).

- Simplified `workstation project adopt` (`scripts/posix/project-adopt.sh`): it now
  only writes `.platformctl/project.json` to register an existing/cloned project — it
  no longer takes a `<template>` argument, no longer backfills any scaffolding files
  (`.editorconfig`, `.gitignore`, `.env.example`, CI files, `.devcontainer/`, etc.). A
  pre-existing codebase keeps its own structure and conventions untouched, managed
  independently by the project itself; `project check` still reports what's missing
  relative to policy, purely informationally.

## 3.7.1

- Fixed `project-check.sh`/`project-adopt.sh` assuming GitHub Actions unconditionally:
  `.github/workflows/ci.yml`/`policy.yml` never execute on Azure DevOps-hosted
  projects. Both now detect the `origin` remote and require/backfill
  `azure-pipelines.yml` instead for `dev.azure.com` remotes — `adopt` skips
  scaffolding the dead GitHub Actions files rather than creating them anyway (it
  does not fabricate `azure-pipelines.yml` either; its content is too
  project-specific to guess, left as a manual follow-up, correctly flagged as
  still missing when actually missing).
- Found while adopting two real company projects: both have private keys/certs
  and, for one, `.env` files for all four environments currently tracked in git
  at `HEAD` — pre-existing, unrelated to this repo, surfaced (not caused) by
  `project-check.sh`'s existing secret-filename scan. Flagged directly rather
  than acted on; this needs coordination with whoever owns those certs/environments,
  not a unilateral fix.

## 3.7.0

Fixed a real gap: pre-existing and freshly-cloned projects had no path into this
governance model at all. `.platformctl/project.json` only ever got created by
`workstation project init`, and both `project check`'s compliance model and the
dashboard's governed-projects panel keyed entirely off that file — a project cloned
straight from GitHub/Azure DevOps was invisible to both, not just non-compliant.

- Added `workstation project adopt <template> [path]`
  (`scripts/posix/project-adopt.sh`): backfills only the scaffolding files missing
  from an existing project relative to a template — never overwrites a file that's
  already there, never runs `git init`, never stages or commits anything. Verified
  against a simulated pre-existing clone: pre-existing README/`.gitignore`/app code
  left untouched, all required files backfilled, idempotent on re-run, nothing
  auto-committed.
- The dashboard's governed-projects panel now surfaces untracked projects too (a git
  repo under a project root with no `.platformctl/project.json`), flagged distinctly
  with a prompt to run `project adopt`, instead of silently omitting them.

## 3.6.3

- Added `workstation ssh-import` (wires `wsl/import-windows-ssh-keys.sh` into the
  `workstation` command) and folded it into the existing autosync cycle
  (`scripts/common/autosync.ps1`/`.sh`): every autosync run now also re-copies any new
  Windows SSH keys into WSL, before the git-sync logic and regardless of git dirty
  state. Deliberately **pure local file copying, never git** — autosync's existing
  refusal to stage secret-bearing files is completely unmodified and unrelated; keys
  never go anywhere near a git commit. Wrapped in its own try/catch so a failure here
  can never abort the git-sync part of the cycle. Verified: the dispatcher wiring and
  the exact snippet added to `autosync.ps1` both run correctly in isolation (did not
  run a live autosync cycle for real, to avoid prematurely committing/pushing
  in-progress working-tree changes as a side effect of testing).

## 3.6.2

- Added `wsl/import-windows-ssh-keys.sh`: copies existing Windows-host SSH key pairs
  into WSL's native filesystem (correct permissions, never referenced in place on
  `/mnt/c`) rather than generating separate WSL-only keys — for when the Windows-side
  keys are already registered with the Git hosts in use. Used it live to fix a real
  blocked `git clone` to Azure DevOps: WSL had generated its own company key that was
  never registered anywhere, while a Windows-side key (tied to the same Azure AD
  identity backing the Azure DevOps org) already worked. Verified both imported
  identities authenticate correctly (`ssh -T git@github-iskarioti`, and Azure DevOps's
  "shell access is not supported" response, which is its normal signature for
  *successful* auth). Deliberately not wired into bootstrap — importing arbitrary
  existing keys is a bigger action than generating a fresh one.

## 3.6.1

- Fixed a real "ready to work" gap: `wsl/configure-git.sh` (git identity + company SSH
  key generation) existed but was never invoked by anything — a fresh WSL bootstrap
  installed `git`/`openssh-client` but left `user.name`/`user.email` unset and
  generated no SSH key, so the very first `git clone` of a company repo would fail or
  silently fall back to password auth. Wired into `wsl/bootstrap.sh`; made
  `configure-git.sh` idempotent (skips re-prompting if identity is already set, and
  no longer hangs if run non-interactively with no identity configured).

## 3.6.0

- Added `workstation dashboard enable|disable|status`: the control plane can now run
  as an always-on background service instead of requiring a manual foreground run.
  WSL/Linux: a systemd user service (`Restart=on-failure`, enabled for
  `default.target`) — as a side effect, keeps the WSL2 VM itself from tearing down
  between uses, since a persistent process is now always running inside it. macOS: a
  LaunchAgent (`RunAtLoad`+`KeepAlive`). Windows: a logon-triggered Scheduled Task
  that wakes WSL (a systemd unit alone can't do that). Verified live: the WSL-side
  service was genuinely enabled and confirmed running via real `systemctl` output;
  the Windows Scheduled Task step hit the same sandbox restriction found earlier for
  autosync/autoupgrade and needs to be completed from a normal terminal.

## 3.5.0

Adopting a "trust before completeness" pass over the control plane and dev-services
subsystem: a real automated test suite, real CI, and a disaster-recovery story, on the
premise that this whole session has repeatedly found bugs that schema validation alone
could never catch.

- Added `platformctl/tests/`: a pytest suite covering auth (password hashing, TOTP,
  session signing/expiry/revocation, login backoff), the status pollers (subprocess
  calls mocked), notification transition logic, and full HTTP integration tests via
  FastAPI's `TestClient`. Found and fixed two real test-isolation bugs while building
  it (module-global `_failed_attempts` leaking state across tests; a stale assertion
  against a template string that had already changed in an earlier phase).
- Added `.github/workflows/behavioral-tests.yml`: runs the pytest suite; brings up
  `services up core` for real and asserts both containers reach `healthy` (a direct
  regression test for the project-directory Compose bug from 3.4.0); validates the
  observability profile's Compose config merges cleanly; runs a live end-to-end
  smoke test (`scripts/ci/control_plane_smoke.py`) against a real `platformctl serve`
  instance.
- Added audit logging: every command run through the command runner is recorded
  (`~/.config/workstation/control-plane/audit.log`, mode 600) and viewable at `/audit`.
- Added session revocation: sessions now carry an ID checked against an active-session
  registry, so logout actually revokes (not just clears a cookie), and a new
  "sign out everywhere" action can invalidate every outstanding session at once.
- Added `workstation backup` / `workstation restore`: an openssl-encrypted backup of
  `~/.config/workstation/` (control-plane credentials, dev-service secrets), labs
  state, and named `platform-*` Docker volumes. Restore stages and confirms before
  touching anything live, moves existing config aside instead of overwriting it, and
  skips existing volumes unless `--force-volumes` is passed. Verified end-to-end
  against throwaway fake-machine state, including wrong-passphrase rejection and the
  moved-aside-not-clobbered safety behavior.
- Added Prometheus alert-rule polling for notifications (`ScrapeTargetDown`,
  `ContainerOOMKilled` — verified the underlying cAdvisor metric actually exists before
  shipping the rule; an early draft referenced one that doesn't). Deliberately pulls
  from Prometheus's API rather than accepting a Grafana webhook: the control plane
  binds `127.0.0.1` only, which a container in Grafana's own network namespace could
  never reach.
- Added `workstation changelog`: drafts a CHANGELOG.md section and suggested semver
  bump from Conventional Commits since the last VERSION change. Preview only, not a
  CI gate — this repo's history predates the convention.
- Fixed the notification poller blocking the entire dashboard event loop during each
  check cycle (synchronous PowerShell/Docker/psutil calls now run via
  `asyncio.to_thread`).

## 3.4.0

- Added an `observability` dev-services profile: `otel-collector`, `prometheus`,
  `loki`, `tempo`, `grafana`, `cadvisor`, `node-exporter` — a full local metrics/logs/
  traces stack, verified end-to-end (all containers healthy, Prometheus scraping all
  targets, Grafana provisioned with datasources).
- Fixed a pre-existing bug in `scripts/posix/services.sh`: `build_compose_args` never
  passed `--project-directory`, so Docker Compose resolved every merged service's
  relative bind-mount paths against the *first* service's directory instead of its
  own. This silently corrupted `workstation services up core` (redis's `redis.conf`
  mount resolved into `postgres/config/`). Fixed by passing `--project-directory`
  explicitly and rewriting every affected service's compose file
  (`postgres`, `redis`, `dev-dashboard`, plus the 5 new observability services with a
  config mount) to reference paths relative to repo root.
- Added `platformctl serve` / `workstation dashboard`: a FastAPI + HTMX web control
  plane, localhost-only, with first-run username/password + TOTP (authenticator app)
  enrollment, signed session cookies, and login rate-limiting with backoff. Verified
  end-to-end: unauthenticated redirect, enrollment, wrong-password rejection, correct
  login, authenticated access, invalid-code rejection, logout, and backoff after
  repeated failures.
- Added the Phase C status/discovery layer: six live dashboard panels (background
  jobs, resource utilization, dev services, governed projects + Dev Containers, lab
  clusters, `ai-runtime`), each backed by `platformctl/platformctl/web/status.py` and
  polled via HTMX. Governed-project discovery (scanning `.platformctl/project.json`
  under policy `projectRoots`) is new bookkeeping — no such registry existed before.
- Added a curated, allowlisted command runner (`platformctl/platformctl/web/commands.py`)
  streaming output live via Server-Sent Events — deliberately a fixed set of exact
  command lines, not a free-text shell box.
- Added the Phase D notification system: a background poller
  (`platformctl/platformctl/web/notify.py`) that fires on state *transitions*
  (background job going unhealthy, a dev service stopping, CPU/memory threshold
  breaches), dispatched to in-app toasts (SSE), Windows-native desktop notifications
  (PowerShell `NotifyIcon`, no new dependency), macOS (`osascript`), Linux
  (`notify-send`), and email (stdlib `smtplib`) — configurable at
  `/settings/notifications`. Fixed a real bug found while verifying this: the
  poller's checks shell out to PowerShell/Docker/psutil and block for real time;
  they now run via `asyncio.to_thread` so a slow check cycle can't freeze every other
  request the dashboard is serving.
- Added `docs/control-plane.md`.

## 3.3.0

- Added `workstation upgrade` (`scripts/common/upgrade.ps1` / `scripts/posix/upgrade.sh`):
  on-demand refresh of winget/brew/apt-managed packages, VS Code extensions and pinned
  fonts, scoped by `workstation.json`'s new `autoUpdate` block and logged to
  `.state/upgrade-<date>.log`.
- Added `workstation autoupgrade enable|disable|once|status`: an off-hours background
  worker (Windows Scheduled Task, systemd user timer, launchd LaunchAgent) that runs
  `workstation upgrade` unattended, gated by a configurable quiet-hours window
  (`autoUpdate.schedule`) and skipped while Docker containers are running so it never
  disturbs active project work.
- Fixed `WorkstationSetupAutoSync` silently failing on every run: the scheduled task
  invoked bare `pwsh.exe`, which resolves through a Store/MSIX App Execution Alias that
  Task Scheduler's process launch cannot follow. `scripts/windows/install-autosync.ps1`
  and the new `install-autoupgrade.ps1` now embed the resolved absolute `pwsh.exe` path.
- Fixed `workstation autosync enable/disable` (and the equivalent new `autoupgrade`
  commands) failing with "term ... is not recognized" on managed/App-Control endpoints:
  `& (Join-Path ...)` invoked a dynamically-computed path directly, which is untrusted
  under ConstrainedLanguage; both control scripts now invoke through `pwsh.exe -File`.
- Fixed `wsl.exe --list --verbose` producing corrupted, spaced-out output in
  `workstation doctor`, `windows/40-health.ps1` and `windows/46-shell-doctor.ps1`
  whenever captured/redirected instead of shown live in a console.
- `workstation doctor` now reports last-run status for the autosync/autoupgrade
  background jobs on all three platforms, surfacing failures automatically instead of
  requiring manual `schtasks`/`systemctl`/`launchctl` inspection.
- Added Dev Container CLI installation to native Linux/macOS bootstrap
  (`scripts/posix/install-devcontainers-cli.sh`), closing a gap where a fresh non-WSL
  machine couldn't satisfy `policy/development.json`'s `requireDevContainer` check.
- Bootstrap now runs `enforce` (informationally) after `doctor` on all three platforms,
  and `docs/new-machine.md` states the concrete "ready to work" contract.
- Fixed every tracked shell script and Git hook (`bootstrap`, `setup`,
  `scripts/posix/*.sh`, `platform/*/*.sh`, `wsl/*.sh`, `.githooks/*`) being committed
  without the executable bit (`core.fileMode=false` on the Windows authoring machine
  meant `chmod` was never recorded) — a fresh Linux/macOS clone could not run
  `./bootstrap` at all until this was fixed.
- Added `docs/auto-update.md`.

## 3.2.0

- Hardened Windows bootstrap for managed endpoints (execution-policy- and
  App-Control-safe `workstation` command shim, VS Code/Windows Terminal/font
  provisioning adjustments).
- Made WSL provisioning idempotent.

## 3.1.0

- Added policy-as-code development-environment enforcement.
- Added `policy/development.json` and schema.
- Added `workstation enforce` with safe `--repair`.
- Added governed project lifecycle commands: templates, init, check, doctor and open.
- Added Dev Container templates for FastAPI, React, Python services, Terraform and research Python.
- Enforced WSL/Linux project roots on Windows and Docker-inside-WSL policy.
- Added project checks for required files, non-root Dev Containers, tracked `.env`
  files, private-key-like filenames and Docker `:latest`.
- Added project metadata under `.platformctl/project.json`.
- Added development-policy validation to platformctl CI.
- Added `policy` to platformctl autosync safe tracked roots.
- Clarified that platformctl autosync never applies to application repositories.
- Updated AI-agent contract for project policy and CI/security invariants.

## 3.0.0

- Rebuilt the workstation as a GitHub-first source-of-truth repository.
- Added one-command Windows and POSIX bootstrap entrypoints.
- Added platform adapters for Windows, Linux and macOS.
- Replaced rsync-style thinking with explicit cp/Copy-Item deployment.
- Added background autosync that validates, applies, commits and pushes the current branch.
- Added pre-commit validation and post-commit apply/push hooks.
- Added safe GitHub publication commands using GitHub CLI.
- Added AI-agent contracts for Codex, Claude, Kimi and Copilot.
- Added GitHub Actions validation on Windows, Linux and macOS.
- Standardized VS Code editor font on official JetBrains Mono.
- Standardized terminal font on JetBrainsMono Nerd Font Mono.
- Added cross-platform VS Code configuration and extension management.
- Added cross-platform Oh My Posh configuration.
- Added secret filename protection to autosync.
- Preserved Windows Terminal PowerShell-only architecture.
- Preserved Docker-inside-WSL architecture on Windows.
- Added global logical `workstation` command after bootstrap.

## 2.5

- Standardized Windows Terminal on exactly one explicit shell: PowerShell 7 GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}`.
- Made that PowerShell 7 profile the Windows Terminal default.
- Added an advanced Tokyo Night Windows Terminal configuration with centered 160×44 launch size.
- Added extensive keyboard-first tab, pane, navigation, incident-bookmark, export-buffer, search and font controls.
- Preserved `Ctrl+C` for shell interrupt and moved clipboard operations to `Ctrl+Shift+C/V`.
- Added command/prompt marks and a 32,767-line operational scrollback.
- Added global Meslo Nerd Font installation through the `NerdFonts` PowerShell resource with `AllUsers` scope.
- Added a safe Windows Terminal settings installer with automatic backup and JSON validation.
- Expanded the PowerShell profile for PSReadLine history/prediction, fzf, zoxide, Git, WSL, Docker, Azure, Kubernetes, Terraform and network diagnostics.
- Added CLM-aware Oh My Posh behavior and a minimal fallback prompt.
- Added `windows/46-shell-doctor.ps1`.
- Hardened the Oh My Posh path renderer against duplicate `spa/spa` paths.
- Documented RemoteSigned/MOTW handling without execution-policy bypasses.

## 2.4

- Replaced Starship with Oh My Posh as the workstation prompt engine.
- Added a compact Tokyo Night Storm-derived Oh My Posh theme.
- Preserved the one-line prompt and short `spa` path abbreviation.
- Added true right-side command duration and clock using an Oh My Posh `rprompt`.
- Retained ble.sh because current Oh My Posh Bash rprompt support uses it.
- Added supported PowerShell ConstrainedLanguage initialization without weakening App Control.
- Windows migration backs up Starship config and attempts to uninstall the WinGet Starship package.
- WSL migration backs up Starship config and removes only the repo-owned local Starship binary.
- Added migration documentation and Oh My Posh diagnostics.

## 2.3

- Added adaptive PowerShell Starship initialization.
- Fixed Starship startup under enterprise PowerShell ConstrainedLanguage.
- CLM now uses a direct `starship prompt` adapter instead of the generated PowerShell initializer that creates restricted .NET process types.
- Added CLM-safe zoxide wrappers.
- Windows shell installer reports the detected PowerShell language mode.
- App Control / WDAC / ConstrainedLanguage are never disabled or bypassed.

## v2.2

- Standardized advanced shell UX on Starship + Tokyo Night.
- Added compact two-component path rendering and engineering directory substitutions.
- Added Bash true right prompt with command duration and time using ble.sh.
- Added WSL shell bootstrap with fzf, zoxide, eza, bat, fd, ripgrep, direnv and tmux.
- Added enterprise-safe PowerShell 7 profile plus Starship/zoxide/fzf installer.
- Fixed WSL Windows-profile discovery for PowerShell ConstrainedLanguage environments.
- Hardened shared SSH configuration: common config copied into WSL; private keys remain OS-specific.
- Fixed Sysinternals package handling by using the Microsoft Store package instead of bypassing hash validation.
- Improved Windows package installation verification and failure reporting.
- Improved `platformctl doctor` with per-command timeouts, explicit TIMEOUT state, and separate Azure authentication status.
