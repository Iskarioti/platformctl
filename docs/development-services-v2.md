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
```

All host-published ports bind to `127.0.0.1`. WSL and the local Windows host can use
the localhost endpoints; Dev Containers attached to `platform-dev` use Docker DNS names.

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
