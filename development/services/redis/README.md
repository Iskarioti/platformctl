# redis

This directory is the canonical configuration package for the `redis` local development service.
It runs `redis/redis-stack-server`, not plain `redis` - RediSearch, RedisJSON, RedisTimeSeries,
and RedisBloom are loaded automatically by the image's own entrypoint, in addition to core Redis.
Auth is passed via the `REDIS_ARGS` environment variable (`--requirepass ...`), not a custom
`command:` override, since the entrypoint appends `REDIS_ARGS` to its own hardcoded startup line.

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults.
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/` — service-specific configuration when required.

Runtime secrets, when needed, are generated outside Git under:
`~/.config/workstation/services/redis.env`.
