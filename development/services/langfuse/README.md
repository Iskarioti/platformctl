# langfuse

This directory is the canonical configuration package for the `langfuse` local
development service - a self-hosted LLM tracing/observability/eval platform for
`templates/projects/rag-app` and `templates/projects/agent-app` (see
`docs/ai-workstation.md`).

Two containers of its own (`langfuse-web`, `langfuse-worker`), plus two
one-shot init containers (`langfuse-postgres-init`, `langfuse-clickhouse-init`)
that idempotently create a dedicated `langfuse` database inside the **shared**
`postgres` and `clickhouse` dev-services on first boot. Langfuse depends on
(`service.json` `dependsOn`) and shares the `postgres`, `redis`, `clickhouse`,
and `garage` dev-services rather than running private copies of each -
`workstation services up langfuse` brings all four up automatically. Garage
(not MinIO: MinIO's open-source project was archived in April 2026 with no
further community builds) provides S3-compatible blob storage for events and
media, in the shared `${GARAGE_DEFAULT_BUCKET:-shared}` bucket under a
`langfuse/` key prefix (see `development/services/garage/README.md` for why
there's no per-consumer bucket isolation yet).

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version for `langfuse-web`/`langfuse-worker`
  only (Postgres/Redis/ClickHouse/Garage versions are each service's own).
- `defaults.env` — non-secret runtime defaults (host port).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.

Runtime secrets, when needed, are generated outside Git under:
`~/.config/workstation/services/langfuse.env`. This includes a pre-seeded
local admin account and a default project's API keys
(`LANGFUSE_INIT_PROJECT_PUBLIC_KEY`/`_SECRET_KEY`), created automatically on
first boot - project templates can start sending traces immediately with no
manual sign-up step in the UI.

Open `http://127.0.0.1:3001` and sign in with `admin@platformctl.local` / the
generated `LANGFUSE_INIT_USER_PASSWORD`. From a project Dev Container already
joined to `platform-dev`, point the LangChain/LangGraph SDK's
`LANGFUSE_HOST=http://dev-langfuse:3000` plus the generated public/secret keys
above.

`workstation services reset langfuse` will not do anything useful for this
service: `reset_service` maps its argument to a literal Compose *service
name* (`rm -sf "$s"`), and none of this bundle's containers are literally
named `langfuse`. Use `services down`/`up` instead, which act on the whole
merged compose file correctly.
