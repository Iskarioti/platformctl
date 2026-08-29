# Shared Development Service Catalog

`platformctl` provides opt-in shared Docker dependencies for local development. The
catalog runs on the single Docker Engine inside WSL on Windows and on native Docker
for Linux/macOS.

## Design rules

- Services do not auto-start after workstation bootstrap.
- All published host ports bind to `127.0.0.1`.
- Projects/Dev Containers should prefer Docker DNS on the shared `platform-dev` network.
- Persistent state uses named Docker volumes.
- Runtime credentials are generated to `~/.config/workstation/dev-services.env` and are never committed.
- Image tags are pinned in `development/services/versions.env`; `latest` is forbidden.
- `workstation services down` preserves data. `reset` is the explicit destructive action.

## Catalog

| Service | Internal endpoint | Default host port | Profile(s) |
|---|---|---:|---|
| PostgreSQL | `dev-postgres:5432` | 5432 | postgres, core, data, all |
| PgBouncer | `dev-pgbouncer:5432` | 6432 | pgbouncer, data, all |
| Redis | `dev-redis:6379` | 6379 | redis, core, all |
| Kafka | `dev-kafka:29092` | 9092 | kafka, messaging, all |
| OpenSearch | `https://dev-opensearch:9200` | 9200 | opensearch, search, all |
| RabbitMQ | `dev-rabbitmq:5672` | 5672 | rabbitmq, messaging, all |
| MongoDB | `dev-mongodb:27017` | 27017 | mongodb, data, all |
| MinIO | `dev-minio:9000` | 9000/9001 | minio, integration, all |
| Mailpit | `dev-mailpit:1025` | 1025/8025 | mailpit, integration, all |

## Commands

```bash
workstation services init
workstation services list
workstation services up core
workstation services up postgres redis kafka
workstation services up messaging
workstation services status
workstation services doctor
workstation services urls
workstation services logs kafka
workstation services stop kafka
workstation services down
```

`core` starts PostgreSQL + Redis. `messaging` starts Kafka + RabbitMQ. `search`
starts OpenSearch. `data` starts PostgreSQL + PgBouncer + MongoDB. `integration`
starts MinIO + Mailpit. `all` starts the complete catalog.

## Governed projects

A project can declare shared dependencies in `.platformctl/project.json`:

```json
{
  "developmentServices": ["postgres", "redis", "kafka"]
}
```

Then run:

```bash
workstation services project-up
```

New projects can declare them at creation time:

```bash
workstation project init fastapi-service orders-api \
  --area company \
  --services postgres,redis,kafka
```

## Credentials

Do not print or commit credentials. The command below prints only the secret-file path:

```bash
workstation services env
```

Applications should load the values from a local secret mechanism or Dev Container
environment injection. `.env.example` remains documentation only.
