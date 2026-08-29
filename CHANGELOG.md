# Changelog

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
