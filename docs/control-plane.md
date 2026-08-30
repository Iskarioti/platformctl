# Web Control Plane

A FastAPI + HTMX web interface over this whole workstation setup: run commands, see
what's running, watch resource utilization, and get notifications — from a browser.

Built in phases; this doc reflects what exists today and is updated as later phases
land.

## Status

- **Phase A — observability stack**: shipped. See `docs/development-services-v2.md`'s
  `observability` profile (`otel-collector`, `prometheus`, `loki`, `tempo`, `grafana`,
  `cadvisor`, `node-exporter`).
- **Phase B — auth skeleton**: shipped (covered below).
- **Phase C — status/discovery layer + command runner**: shipped (covered below).
- **Phase D — notifications**: shipped (covered below), including audit logging,
  session revocation, and Prometheus alert-rule polling added in a later pass.
- **Phase E — full docs**: this document plus `docs/reliability.md`; changelog covers
  all of it.

## Running it

```bash
workstation dashboard            # run once, in the foreground (Ctrl+C to stop)
workstation dashboard --port 9000
```

Binds to `127.0.0.1` only — there is no flag to bind elsewhere. This is deliberate: the
control plane is designed for **localhost-only** access. If you need it from another
device, reach it through an SSH tunnel or VS Code port-forward rather than exposing it
directly.

### Always-on background service

```bash
workstation dashboard enable    # install + start, auto-restart, starts at login
workstation dashboard disable
workstation dashboard status
```

Two parts, mirroring `autosync`/`autoupgrade`:

- **WSL/Linux**: a systemd user *service* (not a periodic timer — this one runs
  continuously): `workstation-dashboard.service`, `Restart=on-failure`, enabled for
  `default.target`. As a side effect, a continuously-running process inside WSL keeps
  the WSL2 VM itself alive — it no longer tears down between uses the way it does when
  nothing is running in it.
- **macOS**: a LaunchAgent (`com.workstation.dashboard`), `RunAtLoad` + `KeepAlive`.
- **Windows**: since `platformctl serve` only runs inside WSL, a Scheduled Task
  (`WorkstationDashboardAutostart`, trigger `AtLogOn`) whose only job is to wake WSL at
  login — an enabled systemd unit does nothing until something actually starts WSL.
  `workstation dashboard enable` on Windows installs both parts in one command.

Verified live: enabling genuinely starts `workstation-dashboard.service` (confirmed via
real `systemctl --user status` output, not just exit code). The Windows Scheduled Task
step could not be created from this sandboxed session (`schtasks.exe /Create` denied —
the same sandbox boundary hit earlier for autosync/autoupgrade) — run
`workstation dashboard enable` yourself once from a normal terminal to pick up the
Windows-side logon trigger; the WSL-side service is already enabled and does not need
to be redone.

## First run: account setup

The first time you visit the app with no account configured, it redirects you to
`/setup` to create the single local operator account (this is a personal, single-user
control plane, not multi-tenant):

1. Choose a username and a password (minimum 12 characters).
2. You're shown a QR code once — scan it into an authenticator app (Google
   Authenticator, Authy, 1Password, etc.). A manual entry key is also shown for
   devices that can't scan. **This is shown exactly once and is not recoverable from
   the UI afterward** — if you lose it, delete the credentials file below and set up
   again.
3. Continue to `/login` and sign in with your password **and** a current 6-digit code
   from your authenticator app.

Every login after that requires both the password and a fresh TOTP code.

## Where credentials live

Everything sensitive lives outside the git repository entirely, under
`~/.config/workstation/control-plane/`:

- `credentials.json` — username, a scrypt password hash + salt (never the raw
  password), and the TOTP secret. Mode 600.
- `session_secret` — random key used to sign session cookies (HMAC-SHA256). Generated
  once on first use. Mode 600.

None of this is ever committed — see `AGENTS.md` rule 4 (never commit secrets). To
reset the account entirely (e.g. lost authenticator), delete
`~/.config/workstation/control-plane/credentials.json` and visit `/setup` again.

## Session and login safety

- Sessions are signed cookies (`HttpOnly`, `SameSite=Strict`), valid 12 hours, but not
  purely stateless: each carries a session ID checked against an active-session
  registry (`~/.config/workstation/control-plane/active_sessions.json`, mode 600), so a
  session can be revoked before its TTL expires. Logout revokes just that session.
  "Sign out everywhere" (`/settings/notifications`) revokes all of them at once — use
  it if you think a session cookie leaked.
- Repeated failed logins from the same client trigger an increasing backoff (starts
  after ~5 failures in a 15-minute window, capped at 5 minutes) — in-memory, resets if
  the process restarts.
- There is no "remember me," no password reset email flow, and no multi-user support
  in this version — it's a single local operator's console for a single workstation.

## Audit log

Every command run through the command runner is appended to
`~/.config/workstation/control-plane/audit.log` (JSONL, mode 600): timestamp, username,
the exact argv that ran, and its exit code. View it at `/audit`. There is currently no
retention/rotation policy — it's a plain append-only file.

## Status/discovery layer (Phase C)

The dashboard (`/`) shows six live, auto-refreshing panels (HTMX polling, no
WebSockets):

- **Background jobs** — autosync/autoupgrade, read via the exact same per-OS commands
  `workstation doctor` uses (`Get-ScheduledTaskInfo` via WSL→Windows interop when
  running under WSL, `systemctl --user` on native Linux, `launchctl` on macOS).
- **Resource utilization** — host CPU/memory/disk via `psutil`, per-container via
  `docker stats`. On Windows this reports the WSL2 VM, not the native Windows host
  (same limitation as `cadvisor`/`node-exporter` in Phase A).
- **Dev services** — `development/catalog.json`'s `platform-dev` Compose project.
- **Governed projects** — discovered by scanning `.platformctl/project.json` under
  `policy/development.json`'s `projectRoots`, cross-referenced against running Dev
  Containers (`docker ps --filter label=devcontainer.local_folder`). There was no
  existing project registry to read from — this scan **is** the registry. A directory
  that's a git repo but has no `.platformctl/project.json` (a pre-existing or freshly
  cloned project — this used to be invisible here entirely) still shows up, flagged
  "untracked", with a prompt to run `workstation project adopt`.
- **Lab clusters** — each `labs/catalog.json` entry's Docker Compose project or
  Kubernetes namespace.
- **ai-runtime** — the shared Ollama container.

### Command runner

A fixed, curated set of buttons (`platformctl/platformctl/web/commands.py`) — **not** a
free-text shell box. Each maps to one exact, hardcoded command line; nothing typed by
the browser is ever interpolated into a shell command. Output streams back live via
Server-Sent Events. Covers: validate, doctor, enforce, upgrade, dev-services
status/doctor/up (core, observability)/down, project templates, and per-lab status.

**Known trade-off**: triggering a command uses an HTTP GET (browsers' native
`EventSource` API used for SSE streaming is GET-only), which is unconventional for
state-changing actions like starting services. Mitigated by: the whole app requires
authentication first, and the session cookie is `SameSite=Strict` so it's never sent
on a cross-site request in the first place — a malicious page can't trigger this by
linking to it.

## Notifications (Phase D)

A background poller (`platformctl/platformctl/web/notify.py`) re-runs the Phase C
status checks on an interval and fires on **transitions**, not on every cycle while a
condition holds — a background job going from healthy to unhealthy, a dev-service
container that was running and stopped, host CPU/memory crossing a configured
threshold. Configure at `/settings/notifications`:

- **In-app**: a toast on the dashboard itself, delivered over the same
  `/notifications/stream` SSE connection every open tab holds.
- **Windows-native**: a real desktop toast, dispatched via a short PowerShell snippet
  (`System.Windows.Forms.NotifyIcon`) shelled out to from WSL — no extra Python
  dependency.
- **macOS**: `osascript display notification` (built-in).
- **Linux**: `notify-send` if present; skipped gracefully on headless WSL without a
  notification daemon.
- **Email**: SMTP (host/port/credentials configured at `/settings/notifications`,
  stored in the same protected `~/.config/workstation/control-plane/notify.json`,
  mode 600).

The poller's checks shell out to PowerShell/Docker/psutil and can take real seconds;
they run via `asyncio.to_thread` so a slow check cycle never blocks the dashboard's
other requests.

### Grafana alert rules

Prometheus (not Grafana) evaluates two starter alert rules
(`development/services/prometheus/config/alert-rules.yml`): `ScrapeTargetDown` (any
scrape target's `up == 0` for 2 minutes) and `ContainerOOMKilled`
(`container_oom_events_total` increasing — verified this is a real cAdvisor metric
before shipping it; a first draft referenced a restart-count metric that doesn't
actually exist in cAdvisor's output and would have silently never fired).

The control plane **polls** Prometheus's `/api/v1/query?query=ALERTS{alertstate="firing"}`
each cycle rather than accepting an inbound webhook from Grafana — deliberately: this
app binds `127.0.0.1` only, which a container in Grafana's own network namespace could
never reach anyway, webhook or not. Pulling keeps the same direction as every other
status check in this file. Newly-firing alerts land in the same in-app/OS-native/email
pipeline as everything else in this section, fired once per firing episode (not
repeated every cycle while still firing).

## What's next (not built yet)

- Deep metrics/log/trace exploration is intentionally **not** reimplemented here —
  open Grafana directly (`http://127.0.0.1:3000` when the `observability` profile is
  running) for that.
- The command runner's allowlist is deliberately narrow for V1 (no per-project
  check/doctor yet, since that needs safe path-parameter handling beyond a fixed
  argv) — expand it as real usage shows what's actually needed.
- Notification trigger conditions are a fixed starting set (job health, service
  stop, CPU/memory thresholds) — expand as real usage shows what's actually useful
  to be alerted on.
