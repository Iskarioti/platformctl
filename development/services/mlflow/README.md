# mlflow

This directory is the canonical configuration package for the `mlflow` local
development service - a self-hosted MLflow Tracking Server for experiment
tracking, run comparison, and a model registry, shared across every project
(`templates/projects/research-python`, `ai`, `rag-app`, `agent-app`, or any
ad-hoc notebook/lab work).

One container (`mlflow`), plus a one-shot init container
(`mlflow-postgres-init`) that idempotently creates a dedicated `mlflow`
database inside the **shared** `postgres` dev-service on first boot. MLflow
depends on (`service.json` `dependsOn`) and shares the `postgres` and `garage`
dev-services rather than running a private database or private blob storage -
`workstation services up mlflow` brings both up automatically. Garage provides
the S3-compatible artifact store, in the shared
`${MLFLOW_STORAGE_BUCKET:-shared}` bucket under a `${MLFLOW_ARTIFACT_PREFIX:-mlflow}/`
key prefix - the same shared-bucket-with-prefix convention `langfuse` already
uses (see `development/services/garage/README.md`).

**Configuration independence** (AGENTS.md, `docs/adr/0003`): `compose.yaml`
here never references another service's variable names directly (no
`${POSTGRES_PASSWORD}`, `${GARAGE_ACCESS_KEY}`, etc.) - it only ever uses its
own `${MLFLOW_*}` names. `service.json`'s `consumes` map declares which of
those come from which dependency; `services.sh`'s `generate_consumed_env()`
resolves the actual values into a generated env file at `up` time. If
`postgres` or `garage` ever renames or replaces one of its variables, only the
one line in `consumes` needs to change - not anything inside this
compose.yaml.

MLflow OSS has no built-in authentication, so this service has no secrets of
its own (`service.json` `secretKeys` is empty) - access control is the same
loopback-only trust boundary every other dev-service uses
(`development/catalog.json` `bindAddress: 127.0.0.1`). MLflow 3's own
Host-header security middleware is explicitly opened with `--allowed-hosts "*"`
for that reason: without it, even a same-machine request through the
published port is rejected outright (confirmed live - the request otherwise
resets the connection).

## Bring it up

```bash
workstation services up mlflow
```

## Endpoints

| What | URL |
| --- | --- |
| MLflow UI/API | http://localhost:5001 |

## Point a project at it

```python
import mlflow
mlflow.set_tracking_uri("http://dev-mlflow:5000")  # from inside a project's Dev Container, on platform-dev
# or, from the host: http://localhost:5001
mlflow.set_experiment("my-experiment")
```

Artifacts are written straight to Garage via boto3 (`--default-artifact-root
s3://shared/mlflow/`) - a client logging artifacts needs the same
`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`MLFLOW_S3_ENDPOINT_URL`/
`MLFLOW_BOTO_CLIENT_ADDRESSING_STYLE=path` environment variables the server
itself uses (see `compose.yaml`) - pull them from
`~/.config/workstation/services/garage.env` the same way this service's own
`consumes` map does.
