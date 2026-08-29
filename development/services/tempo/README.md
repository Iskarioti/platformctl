# tempo

This directory is the canonical configuration package for the `tempo` local
development service. Single-process, filesystem-backed trace store; receives traces
from `otel-collector` over an internal-only OTLP gRPC endpoint (not exposed to the
host). Queried by `grafana`.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.
- `config/tempo.yaml` — single-binary local storage configuration.

No runtime secrets are required.
