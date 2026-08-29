# platformctl Docker Development Services

This directory is canonical source for the shared local dependency catalog. Use the
`workstation services ...` command rather than invoking this Compose file directly.

Tracked:
- `compose.yaml`: service topology, localhost bindings, health checks, volumes.
- `versions.env`: pinned image versions.
- `.env.example`: documentation only; contains no usable credentials.
- `config/`: non-secret service configuration.

Untracked/outside Git:
- `~/.config/workstation/dev-services.env`: generated runtime credentials.
- Docker named volumes containing local development data.

See `docs/development-services.md`.
