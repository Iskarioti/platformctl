# loki

This directory is the canonical configuration package for the `loki` local development
service. Single-process, filesystem-backed log store; receives logs from
`otel-collector` over its native OTLP-logs endpoint. Queried by `grafana`.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.
- `config/loki-config.yaml` — single-binary local storage configuration.

No runtime secrets are required.
