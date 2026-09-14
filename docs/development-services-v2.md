# Modular Development Services

Each service owns its own configuration package under `development/services/<service>/`:

- `service.json`
- `versions.env`
- `defaults.env`
- `.env.example`
- `compose.yaml`
- `config/` where needed
- `README.md`

Runtime secrets are not tracked. They are generated per service under:

`~/.config/workstation/services/<service>.env`

The root catalog is `development/catalog.json`.

Typical commands:

```bash
workstation services list
workstation services config redis
workstation services up core
workstation services up redisinsight
workstation services up ui
workstation services urls
workstation services doctor
workstation services scaffold <name>      # new service's file skeleton, pre-wired to consumes
workstation services rotate <service>     # regenerate + apply a secret - safe subset only,
                                           # see docs/secrets-rotation.md for the rest
```

All host-published ports bind to `127.0.0.1`. WSL and the local Windows host can use
the localhost endpoints; Dev Containers attached to `platform-dev` use Docker DNS names.

## Always-on services (survive Docker/WSL restart and PC reboot)

```bash
workstation services autostart enable redis redisinsight   # default target set if omitted
workstation services autostart disable
workstation services autostart status
```

Two parts, mirroring `workstation dashboard enable`/`docs/control-plane.md`:

- **Docker's own restart policy**: each target service's own `compose.yaml`
  carries `restart: unless-stopped` (currently set on `redis` and
  `redisinsight`) - Docker resumes the container itself whenever its daemon
  starts, with no extra scripting needed, for as long as WSL itself is
  running.
- **Windows**: since Docker only runs inside WSL, and a restart policy does
  nothing until something actually starts the WSL instance, a Scheduled Task
  (`WorkstationDevServicesAutostart`, trigger `AtLogOn`) wakes WSL at login
  and explicitly runs `services up <targets>` - the same wake-WSL role
  `WorkstationDashboardAutostart` plays for the dashboard. `workstation
  services autostart enable` on Windows installs both parts (WSL-side +
  logon task) in one command; run from inside WSL directly, it only does the
  WSL-side half and expects the Windows-side command to be run once too.
  Runs fully silently - routed through `wscript.exe`/`run-hidden.vbs` like
  every other scheduled task this repo installs, so no terminal window
  appears at login (confirmed live 2026-09-14: the task originally launched
  `wsl.exe` directly and flashed a visible console window every logon -
  Task Scheduler's own "Hidden" task setting does not suppress the window a
  directly-launched .exe opens; fixed, re-registered, and verified quiet).

Add `restart: unless-stopped` to any other dev-service's `compose.yaml` to
make it eligible, then include its id in the `autostart enable`/Scheduled
Task target list.

## Configuration independence

Each service's `compose.yaml`, `versions.env`, `defaults.env`, and
`.env.example` must be self-contained: **a service must never reference
another service's variable names directly** (no `${POSTGRES_PASSWORD}`,
`${CLICKHOUSE_USER}`, etc. inside a different service's `compose.yaml`). This
holds even when the service functionally depends on another one for actual
infrastructure (its own database inside a shared Postgres, its own bucket in
a shared object store, and so on) - runtime dependencies via `service.json`'s
`dependsOn` are fine and expected; reaching directly into a dependency's
specific variable names to get there is not, since it silently breaks if that
dependency ever renames, re-versions, or gets replaced.

When a service genuinely needs a value that only a dependency can produce
(most commonly: that dependency's own generated credential), declare a
`consumes` map in `service.json`:

```json
"consumes": {
  "LANGFUSE_DB_PASSWORD": "postgres:POSTGRES_PASSWORD"
}
```

The key is the OWN variable name the service's `compose.yaml` actually uses;
the value is `<dependency-service-id>:<dependency's variable name>`.
`scripts/posix/services.sh`'s `generate_consumed_env()` resolves each entry
(searching the dependency's `versions.env`, `defaults.env`, and generated
secret file, in that order) into a generated env file merged into the same
`docker compose` invocation - the dependent's own `compose.yaml` never has
to know the dependency's internal naming, only its own. See
`development/services/langfuse/service.json` for a full example (it consumes
its Postgres user/password, Redis password, ClickHouse user/password, and
Garage access/secret key/bucket this way, including the dependency's own
pinned image/version for its init containers rather than duplicating those
pins).
