# grafana

This directory is the canonical configuration package for the `grafana` local
development service. Prometheus/Loki/Tempo are pre-provisioned as datasources
(`config/provisioning/datasources/`) — nothing to click through on first login.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/provisioning/` — datasource provisioning.

Runtime secrets are generated outside Git under:
`~/.config/workstation/services/grafana.env`.

Login: `admin` / the generated `GRAFANA_ADMIN_PASSWORD` (see
`workstation services urls` or the secrets file above).
