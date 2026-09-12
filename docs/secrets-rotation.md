# Secrets Rotation

Every secret this repo generates lives outside Git, under
`~/.config/workstation/` (dev-service credentials in `services/*.env`,
control-plane credentials in `control-plane/`) - see `AGENTS.md` rule 4 and
`docs/control-plane.md` "Where credentials live". Nothing here is ever
committed, so rotation is a local operational task, not a Git operation.

Rotating a credential is only safe automatically when nothing beyond the
running container itself checks it live against the env var. Several
dev-services instead persist the credential separately (in the database's own
user table, an internal auth index, or on-disk state) the first time they
boot - regenerating the env var alone then desyncs it from what the running
service actually expects, locking you out rather than rotating anything.
Each service below was checked directly (its `compose.yaml`, or live testing)
before being placed in one list or the other - don't assume, verify the same
way if a new dev-service is ever added here.

## Automated (`workstation services rotate <service>`)

```bash
workstation services rotate redis
workstation services rotate qdrant
workstation services rotate minio
workstation services rotate open-webui
```

Backs up the current secret file (`<service>.env.pre-rotate.<timestamp>`),
generates a fresh one, and recreates the container with it - verified live on
this machine for `redis` and `qdrant`: the old credential is rejected
immediately afterward, the new one works. Any project's own `.env` that
copied the old value by hand needs updating separately - this only rotates
the dev-service's own copy.

These four are safe because the credential is checked live, every time,
straight from the env var:

- **redis** - `requirepass` is a runtime config, not part of the RDB/AOF
  dataset.
- **qdrant** - `QDRANT__SERVICE__API_KEY` is checked per-request, nothing
  persisted separately.
- **minio** - the root user's credentials are always env-derived (unlike any
  additional IAM users, which this repo doesn't create).
- **open-webui** - `WEBUI_SECRET_KEY` signs sessions/JWTs; rotating it just
  invalidates existing sessions (forces re-login), nothing is lost.

## Manual (everything else)

`workstation services rotate` refuses these outright and points here,
instead of guessing:

| Service | Why automated rotation is unsafe | Correct procedure |
|---|---|---|
| `postgres` | `POSTGRES_PASSWORD` only sets the password at first data-directory init; the real password lives in the running database | `docker exec -it dev-postgres psql -U <user> -c "ALTER USER <user> WITH PASSWORD '<new>'"`, then update `~/.config/workstation/services/postgres.env` to match and restart every service that consumes it (`langfuse`, `mlflow`, any project - check `consumes` maps in `development/services/*/service.json`) |
| `pgadmin` | `PGADMIN_DEFAULT_PASSWORD` only applies at first container init; stored in pgadmin's own internal config afterward | Change it from pgadmin's own UI (User menu -> Change Password), or delete the `platform-pgadmin-data` volume to force re-init (loses saved server connections) |
| `opensearch` | Credentials live in OpenSearch Security's internal index after first boot | Use the OpenSearch Security REST API or `securityadmin.sh` to change the internal user's password; env var alone does nothing after first boot |
| `rabbitmq` | The default user's password is stored in RabbitMQ's own Mnesia database | `docker exec dev-rabbitmq rabbitmqctl change_password <user> <new>`, then update the env file to match |
| `mongodb` | Root credentials are stored in MongoDB's own `admin` auth database after first init | Connect with `mongosh` and run `db.changeUserPassword(<user>, <new>)` against the `admin` database, then update the env file to match |
| `grafana` | The admin password is stored in Grafana's own SQLite database after first boot | `docker exec dev-grafana grafana-cli admin reset-admin-password <new>`, then update the env file to match |
| `garage` | `GARAGE_DEFAULT_ACCESS_KEY`/`GARAGE_DEFAULT_SECRET_KEY` only seed the *default* key at first cluster init - Garage manages keys itself afterward | `docker exec dev-garage /garage key rotate <key-id>` (or create a new key and retire the old one via `garage key delete`) - see [Garage's key-management docs](https://garagehq.deuxfleurs.fr/documentation/reference-manual/cli/#access-key-management) |
| `clickhouse` | User credentials are stored in ClickHouse's own user config/state after first boot | Use `ALTER USER <user> IDENTIFIED BY '<new>'` via `clickhouse-client`, then update the env file to match |
| `langfuse` | `SALT`/`ENCRYPTION_KEY` encrypt values already persisted in the shared Postgres - rotating them makes existing encrypted rows undecryptable | Not safely rotatable without a data migration (re-encrypt every affected row under the new key first). If the key is suspected compromised, treat existing encrypted data as compromised too and reset the langfuse database/project instead of rotating in place. `NEXTAUTH_SECRET` alone (JWT-session-only) is as safe as `open-webui`'s key - just delete it from the env file and let it regenerate, then restart |
| `redisinsight` | `REDISINSIGHT_ENCRYPTION_KEY` encrypts data already saved in its own volume | Rotating it makes existing saved connections/data unreadable - only do this alongside `workstation services reset redisinsight --yes` (which discards that volume) |

## Control plane

`~/.config/workstation/control-plane/session_secret` signs session cookies
only (`docs/control-plane.md`) - delete it and it regenerates on next start,
invalidating every existing session (forces re-login everywhere) with no
data loss. The account password/TOTP secret in `credentials.json` has no
in-place rotation - delete the file and visit `/setup` again to create a new
account, same as the lost-authenticator recovery path already documented in
`docs/control-plane.md`.

## GitHub tokens

Any personal access token used by `workstation publish`/`gh` is scoped and
owned by GitHub, not generated by this repo - rotate it from
https://github.com/settings/tokens and re-run `gh auth login`, same as any
other machine.

## Project secrets

A governed project's own `.env` (copied dev-service credentials, API keys)
rotates the same way it was created: re-copy the new value after rotating
the underlying dev-service above, or regenerate the project's own secret if
it's the project's, not a dev-service's.
