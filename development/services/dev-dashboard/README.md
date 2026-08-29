# dev-dashboard

This directory is the canonical configuration package for the `dev-dashboard` local development service.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/` — service-specific configuration when required.

Runtime secrets, when needed, are generated outside Git under:
`~/.config/workstation/services/dev-dashboard.env`.
