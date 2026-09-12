# AI/ML Workstation

A governed, local-first lifecycle for testing models, building MCP servers, and
developing RAG/agentic architectures before anything reaches production. It follows
this repo's existing three-tier mechanism instead of inventing a fourth one:

- **dev-service** (stable, shared, always-on infra) — `ai-runtime` (Ollama), the
  `qdrant` dev-service, `open-webui` (chat UI / prompt-engineering interface),
  `langfuse` (LLM tracing/observability), and `mlflow` (experiment tracking +
  model registry) — the latter two depending on the shared
  `postgres`/`redis`/`clickhouse`/`garage` dev-services rather than private
  copies of each.
- **project template** (one-off app scaffolding) — `mcp-server`, `rag-app`,
  `agent-app`.
- **lab** (disposable, pre-production architecture validation) — `labs/ai/rag-pipeline`
  and `labs/ai/agent-mesh`. See `docs/labs.md` for the general lab philosophy:
  production is never deployed directly from lab state, only proven patterns
  translated into reviewed IaC.

## 1. Local model testing

```bash
workstation models up              # start the shared Ollama runtime
workstation models pull gemma3:4b  # or gemma3:1b, gemma3:12b, nomic-embed-text, ...
workstation models list
workstation models run gemma3:4b   # interactive chat
workstation models status
workstation models down
```

`ai-runtime`'s `ollama` container joins both the `ai-runtime` network and
`platform-dev` (the same network `workstation services` uses) — any project
container that joins `platform-dev` via `runArgs: ["--network=platform-dev"]` in its
own `devcontainer.json` reaches `ollama:11434` directly, no extra networking.

## 2. Vector storage for RAG

```bash
workstation services up qdrant
```

Same 7-file dev-service pattern as every other entry in `development/catalog.json`.
Its API key is a generated secret at `~/.config/workstation/services/qdrant.env` —
copy the real value into a project's own `.env` (never commit it); any app using it
must actually call `load_dotenv()` to pick it up.

## 3. Prompt engineering interface

```bash
workstation services up open-webui
```

Self-hosted chat UI (`ghcr.io/open-webui/open-webui`) for the shared Ollama
runtime — reaches `ollama:11434` over `platform-dev`, same as every other
service. Open `http://127.0.0.1:8081` and create the first account (becomes the
local admin); its API routes (`/ollama/api/*`) require that login, by design.
Its data volume (`platform-open-webui-data`) also caches a small embedding model
it downloads from Hugging Face on first boot - if that first boot gets
interrupted mid-download, the next restart just re-downloads it, it does not
loop or fail permanently.

## 4. LLM tracing/observability

```bash
workstation services up langfuse
```

Self-hosted [Langfuse](https://langfuse.com/) (`langfuse/langfuse` +
`langfuse/langfuse-worker`, both `4.27.0`). Rather than bundling its own
private Postgres/Redis/ClickHouse/S3, it **depends on and shares** the
`postgres`, `redis`, `clickhouse`, and `garage` dev-services
(`service.json` `dependsOn`) - `workstation services up langfuse` brings all
four up automatically. Two one-shot init containers
(`langfuse-postgres-init`, `langfuse-clickhouse-init`) idempotently create a
dedicated `langfuse` database inside the shared Postgres/ClickHouse on first
boot, so Langfuse doesn't pollute the shared `platformdev`/`default`
databases other consumers use. [Garage](https://garagehq.deuxfleurs.fr/)
(not MinIO: MinIO's open-source project was archived in April 2026 with no
further community builds) provides S3-compatible blob storage - Langfuse
uses the shared bucket under a `langfuse/` key prefix, since there's no
per-consumer bucket isolation yet (see `development/services/garage/README.md`).
Only `langfuse-web` publishes a host port (`http://127.0.0.1:3001`).

A local admin account and a default project's API keys are pre-seeded on first
boot (`LANGFUSE_INIT_*`, generated into `~/.config/workstation/services/langfuse.env`) -
`rag-app` and `agent-app` (below) already read these as `LANGFUSE_PUBLIC_KEY`/
`LANGFUSE_SECRET_KEY` and trace every LLM call automatically via
`langfuse.langchain.CallbackHandler`, with graceful no-op fallback if those
keys aren't set. To instrument your own LangChain/LangGraph code the same way:

```python
from langfuse.langchain import CallbackHandler  # reads LANGFUSE_* env vars

handler = CallbackHandler()
result = my_chain.invoke(input, config={"callbacks": [handler]})
```

Real issues surfaced verifying this end-to-end, worth knowing if any of this
ever needs rebuilding from scratch:
- ClickHouse is pinned to `25.12.11` deliberately, not "the actual latest"
  (26.x, which this repo would normally prefer) - Langfuse 4.27.0's worker hit
  `Numeric value is out of range for DateTime64` and silently dropped every
  event against ClickHouse 26.8.2. For a vendor-tested multi-service stack
  like this, match the vendor's own pinned companion version rather than
  grabbing the newest independently-verified tag for each component - if
  another consumer of the shared `clickhouse` service needs a newer version,
  verify Langfuse still works before bumping it, or give that consumer its
  own private instance instead.
- Langfuse v4 replaced the old REST trace-ingestion/fetch API
  (`/api/public/ingestion` with `trace-create` events, `GET
  /api/public/traces/{id}`) with OTLP-based ingestion - use the SDK (as
  above), not hand-rolled REST calls against those old endpoints. Newly
  ingested events land first in ClickHouse's raw `events_full`/`events_core`
  tables; the `analytics_traces`/`observations` tables (and the UI) are
  populated from those by a separate scheduled propagation job, not
  synchronously.
- `workstation services reset langfuse` is a no-op: `reset_service` maps its
  argument to a literal Compose service name, and none of Langfuse's own
  containers are literally named `langfuse`. Use `services down`/`up` instead.

Tracing alone only shows what happened, not whether it was any good -
`rag-app` and `agent-app` each ship their own `scripts/eval_dataset.py` to
close that gap for real: it runs a golden Q&A set (the same LLM-judge idea
`labs/ai/rag-pipeline`'s `quality` test uses) through the app's own traced
code path (`get_store()`+generation for `rag-app`, `graph.invoke` for
`agent-app`), as a real Langfuse **dataset experiment**
(`langfuse.run_experiment`) instead of a disposable lab - every run is a
real, inspectable dataset run in the Langfuse UI, not just a pass/fail line
in a terminal. See either template's README "Quality evaluation against a
real Langfuse dataset".

## 5. Experiment tracking + model registry

```bash
workstation services up mlflow
```

Self-hosted [MLflow](https://mlflow.org/) Tracking Server (`ghcr.io/mlflow/mlflow`,
the `-full` image variant - it's the one with `psycopg2`/`boto3` preinstalled,
the plain image has neither). Same dependency-sharing pattern as Langfuse: it
depends on and shares the `postgres` and `garage` dev-services rather than
running a private SQLite file or private blob storage (`service.json`
`dependsOn`) - `workstation services up mlflow` brings both up automatically.
One init container (`mlflow-postgres-init`) idempotently creates a dedicated
`mlflow` database on first boot. Artifacts land in the shared Garage bucket
under an `mlflow/` key prefix, the same shared-bucket-with-prefix convention
Langfuse uses (see `development/services/garage/README.md`).

```python
import mlflow
mlflow.set_tracking_uri("http://dev-mlflow:5000")  # from a project's Dev Container
mlflow.set_experiment("my-experiment")
with mlflow.start_run():
    mlflow.log_param("lr", 0.01)
    mlflow.log_metric("accuracy", 0.94)
```

From the host instead of a container: `http://localhost:5001`, and the same
four env vars a client needs to log artifacts directly to Garage
(`AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`/`MLFLOW_S3_ENDPOINT_URL`/
`MLFLOW_BOTO_CLIENT_ADDRESSING_STYLE=path`) live in
`~/.config/workstation/services/garage.env` (see `development/services/mlflow/README.md`).

MLflow OSS ships no authentication at all, so unlike every other dev-service
here it has no generated secret of its own - the loopback-only host binding
*is* its access control. MLflow 3 added its own Host-header security
middleware on top of that; it's opened with `--allowed-hosts "*"` in
`compose.yaml`; without that flag, confirmed live, even a same-machine request
through the published port gets its connection reset outright.

## 6. Project templates

```bash
workstation project init mcp-server <name> --area labs   # or company/platform/...
workstation project init rag-app <name>
workstation project init agent-app <name>
```

- **`mcp-server`** — Python, official `mcp` SDK (`FastMCP`). The Dev Container
  includes a Node feature so the MCP Inspector runs alongside it with no extra
  setup: `npx @modelcontextprotocol/inspector python app/server.py` (interactive),
  or `npx @modelcontextprotocol/inspector --cli python app/server.py --method
  tools/list` / `--method tools/call --tool-name <name> --tool-arg k=v` for scripted
  checks.
- **`rag-app`** — FastAPI + LangChain + `langchain-qdrant` + `langchain-ollama`.
  Joins `platform-dev` to reach `ollama`, `dev-qdrant`, and (optionally)
  `dev-langfuse` by name.
- **`agent-app`** — FastAPI + LangGraph (`StateGraph`, one `respond` node by
  default) + `langchain-ollama`. Same `platform-dev` join.

Both `rag-app` and `agent-app` trace every LLM call to Langfuse automatically
if `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` are set in `.env` (see section 4
above) - unset, they just run without tracing.

All three's FastAPI endpoints take plain scalar parameters (`text: str`,
`question: str`) with no Pydantic body model, so FastAPI treats them as **query
parameters** even on `POST` — test with `curl -X POST '.../invoke?question=...'`,
not a JSON body.

## 7. Architecture validation before production

```bash
workstation lab toolchain install         # kubectl, helm, k3d (one-time)
workstation lab up rag-pipeline --runtime docker
workstation lab test rag-pipeline smoke --runtime docker
workstation lab test rag-pipeline qdrant-outage --runtime docker
workstation lab test rag-pipeline quality --runtime docker
workstation lab destroy rag-pipeline --runtime docker --yes

workstation lab up agent-mesh --runtime docker
workstation lab test agent-mesh smoke --runtime docker
workstation lab test agent-mesh node-failure --runtime docker
workstation lab destroy agent-mesh --runtime docker --yes
```

- **`rag-pipeline`** — its own disposable Ollama + Qdrant, seeded by a real
  ingest/embed/store/retrieve round-trip. `smoke` asserts retrieval correctness and
  score; `qdrant-outage` stops Qdrant mid-session, confirms callers see a clean
  failure (not a hang), and confirms data survives the restart (a real named
  volume — the Kubernetes variant of this test instead proves the *service*
  recovers after its pod is replaced, since that runtime's manifests use
  `emptyDir`, not a PVC); `quality` runs a golden question/answer set through
  real retrieval + generation, then grades each answer with a second LLM call
  acting as judge, and fails if the mean score drops below `0.6` — a real
  answer-quality regression gate, not just an infra-outage check. Confirmed
  live that `gemma3:1b` (used for the fast generation step) is too weak a
  judge — it scored an obviously-correct paraphrase `0.1` — so judging
  specifically uses `gemma3:4b` instead.
- **`agent-mesh`** — three independent replicas of a minimal LangGraph agent
  behind Ollama. `smoke` confirms all three answer independently (each is a real,
  separate model invocation); `node-failure` stops one replica and confirms the
  other two keep serving — proving there's no single point of failure in the
  pattern, not validating any specific production app.

Both labs' Qdrant/Ollama data volumes persist across `lab up`/`lab down` (only
`lab destroy` clears them) — their test scripts tolerate re-running against an
already-seeded lab (a `409` on collection creation is not a failure).

Both labs also run under `--runtime kubernetes` (Deployments/Services behind
`kubectl apply -k`, matching `redis-cluster`'s established layout) - requires
`workstation lab toolchain install` first (`kubectl`, Helm, `k3d`) and
`workstation lab cluster create`. `agent-mesh` additionally needs its
`prepare-kubernetes.sh` hook (invoked automatically by `lab up --runtime
kubernetes`) to build its app image and `k3d image import` it into the
`platform-labs` cluster, since it isn't published to a registry.

## 8. Production

Never deploy from lab or dev-service state directly. Package a template's own
`.devcontainer/Dockerfile` as the production image base (swap the dev
`postCreateCommand` install for `pip install .`), point `OLLAMA_BASE_URL` /
`QDRANT_URL` at real production endpoints via environment variables, and translate
whatever the relevant lab proved (retrieval latency/quality bounds, outage/failover
behavior) into reviewed Terraform/Helm/Ansible — by hand, same as every other lab
in this repo.
