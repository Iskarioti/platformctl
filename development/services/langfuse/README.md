# langfuse

This directory is the canonical configuration package for the `langfuse` local
development service - a self-hosted LLM tracing/observability/eval platform for
`templates/projects/rag-app` and `templates/projects/agent-app` (see
`docs/ai-workstation.md`).

Six containers behind one catalog entry: `langfuse-web` (UI + API),
`langfuse-worker` (async ingestion), `langfuse-postgres` (app data),
`langfuse-clickhouse` (trace/analytics storage), `langfuse-redis`
(queue/cache), and `langfuse-garage` (S3-compatible blob storage for events
and media - using [Garage](https://garagehq.deuxfleurs.fr/), not MinIO: MinIO's
open-source project was archived in April 2026 with no further community
builds, so Garage - actively maintained, built for exactly this use case - was
used instead). Only `langfuse-web` publishes a host port; the other five are
reachable only from containers already on `platform-dev`.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version for all six containers.
- `defaults.env` — non-secret runtime defaults (host port).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/garage.toml` — Garage's static config (secrets injected via env
  vars instead, `GARAGE_RPC_SECRET`/`GARAGE_ADMIN_TOKEN`, not this file).

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

`langfuse-garage` has no Docker healthcheck: its image is built `FROM scratch`
(just the static binary, no shell/wget/curl at all), so `depends_on` uses
`condition: service_started` for it instead of `service_healthy`.
