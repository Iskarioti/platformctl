# garage

This directory is the canonical configuration package for the `garage` local
development service - shared S3-compatible object storage
([Garage](https://garagehq.deuxfleurs.fr/), not MinIO: MinIO's open-source
project was archived in April 2026 with no further community Docker builds).
Currently used by `langfuse` (event/media blob storage), and available for
any future dev-service or project that needs S3-compatible storage rather
than running a private instance.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults (host port, default bucket
  name).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/garage.toml` — Garage's static config (secrets injected via env
  vars instead - `GARAGE_RPC_SECRET`/`GARAGE_ADMIN_TOKEN` - not this file).

Runtime secrets (RPC secret, admin token, and a default S3 access/secret key
pair), when needed, are generated outside Git under:
`~/.config/workstation/services/garage.env`.

On first boot (`--single-node --default-bucket`), Garage auto-creates one
bucket (`GARAGE_DEFAULT_BUCKET`, default `shared`) and one access key scoped
to it, from the generated secrets above - there is currently no per-consumer
bucket isolation; consumers share this one bucket and should namespace their
own objects with a key prefix (Langfuse does this: `events/`, `media/`).

`garage` has no Docker healthcheck: its image is built `FROM scratch` (just
the static binary, no shell/wget/curl at all), so dependents use `condition:
service_started` instead of `service_healthy`.

From a project Dev Container already joined to `platform-dev`, reach it at
`dev-garage:3900` (S3 API) - the same pattern used to reach
`redis`/`postgres`/`clickhouse`/`ollama`.
