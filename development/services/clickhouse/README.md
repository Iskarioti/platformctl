# clickhouse

This directory is the canonical configuration package for the `clickhouse`
local development service - a shared OLAP/analytics database. Currently used
by `langfuse` (its own dedicated `langfuse` database inside this shared
instance), and available for any future dev-service or project that needs
one rather than running a private instance.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults (user, ports).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.

Runtime secrets (the admin password), when needed, are generated outside Git
under: `~/.config/workstation/services/clickhouse.env`.

**Version pin note**: `25.12.11`, not "the actual latest" (26.x at the time
this was pinned). ClickHouse 26.8.2 silently dropped every event written by
Langfuse 4.27.0's worker (`Numeric value is out of range for DateTime64`) -
Langfuse's own reference deployment pins ClickHouse `25.12`. If another
consumer needs a newer ClickHouse, verify Langfuse still works against it
before bumping this shared instance's version - or give that consumer its
own private ClickHouse instead of sharing this one.

From a project Dev Container already joined to the `platform-dev` network,
reach it at `dev-clickhouse:8123` (HTTP) or `dev-clickhouse:9000` (native) -
the same pattern used to reach `redis`/`postgres`/`ollama`. Each consumer
should use its own logical database inside this shared instance (`CREATE
DATABASE IF NOT EXISTS <name>`) rather than writing into `default`.
