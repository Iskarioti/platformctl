# otel-collector

This directory is the canonical configuration package for the `otel-collector` local
development service.

Single ingestion point for the observability profile: receives OTLP traces/metrics/logs
from instrumented applications and fans them out to `tempo` (traces), `prometheus`
(metrics, via its own scrape of this collector), and `loki` (logs).

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation (none needed).
- `compose.yaml` — service topology.
- `config/otel-collector-config.yaml` — receiver/exporter/pipeline configuration.

No runtime secrets are required.
