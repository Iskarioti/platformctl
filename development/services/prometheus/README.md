# prometheus

This directory is the canonical configuration package for the `prometheus` local
development service.

Scrapes `otel-collector` (application metrics), `cadvisor` (container metrics) and
`node-exporter` (host/WSL-VM metrics). Queried by `grafana`.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.
- `config/prometheus.yml` — scrape configuration.

No runtime secrets are required.
