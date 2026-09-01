# AI/ML Workstation

A governed, local-first lifecycle for testing models, building MCP servers, and
developing RAG/agentic architectures before anything reaches production. It follows
this repo's existing three-tier mechanism instead of inventing a fourth one:

- **dev-service** (stable, shared, always-on infra) — `ai-runtime` (Ollama), the
  `qdrant` dev-service, `open-webui` (chat UI / prompt-engineering interface), and
  `langfuse` (LLM tracing/observability).
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

Self-hosted [Langfuse](https://langfuse.com/) (`langfuse/langfuse` + `langfuse/langfuse-worker`,
both `4.27.0`) - six containers behind one catalog entry: the two Langfuse
services plus their own private Postgres, Redis, ClickHouse, and
[Garage](https://garagehq.deuxfleurs.fr/) (S3-compatible blob storage - not
MinIO, whose open-source project was archived in April 2026 with no further
community builds). Only `langfuse-web` publishes a host port
(`http://127.0.0.1:3001`); the rest are reachable only from `platform-dev`.

A local admin account and a default project's API keys are pre-seeded on first
boot (`LANGFUSE_INIT_*`, generated into `~/.config/workstation/services/langfuse.env`
alongside every other secret this service needs) - a project can start sending
traces immediately with the `langfuse` Python SDK:

```python
import os
os.environ["LANGFUSE_HOST"] = "http://dev-langfuse:3000"  # from a container on platform-dev
os.environ["LANGFUSE_PUBLIC_KEY"] = "..."  # LANGFUSE_INIT_PROJECT_PUBLIC_KEY
os.environ["LANGFUSE_SECRET_KEY"] = "..."  # LANGFUSE_INIT_PROJECT_SECRET_KEY

from langfuse import Langfuse
lf = Langfuse()
with lf.start_as_current_observation(as_type="span", name="my-trace") as span:
    span.update(input=..., output=...)
```

Two real issues surfaced verifying this end-to-end, worth knowing if this
service ever needs rebuilding from scratch:
- Its ClickHouse version is pinned to `25.12.11` deliberately, not "the
  actual latest" (26.x, which this repo would normally prefer) - Langfuse
  4.27.0's worker hit `Numeric value is out of range for DateTime64` and
  silently dropped every event against ClickHouse 26.8.2. For a
  vendor-tested multi-service stack like this, match the vendor's own pinned
  companion version rather than grabbing the newest independently-verified
  tag for each component.
- Langfuse v4 replaced the old REST trace-ingestion/fetch API
  (`/api/public/ingestion` with `trace-create` events, `GET
  /api/public/traces/{id}`) with OTLP-based ingestion - use the SDK (as
  above), not hand-rolled REST calls against those old endpoints. Newly
  ingested events land first in ClickHouse's raw `events_full`/`events_core`
  tables; the `analytics_traces`/`observations` tables (and the UI) are
  populated from those by a separate scheduled propagation job, not
  synchronously.

## 5. Project templates

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
  Joins `platform-dev` to reach both `ollama` and `dev-qdrant` by name.
- **`agent-app`** — FastAPI + LangGraph (`StateGraph`, one `respond` node by
  default) + `langchain-ollama`. Same `platform-dev` join.

All three's FastAPI endpoints take plain scalar parameters (`text: str`,
`question: str`) with no Pydantic body model, so FastAPI treats them as **query
parameters** even on `POST` — test with `curl -X POST '.../invoke?question=...'`,
not a JSON body.

## 6. Architecture validation before production

```bash
workstation lab toolchain install         # kubectl, helm, k3d (one-time)
workstation lab up rag-pipeline --runtime docker
workstation lab test rag-pipeline smoke --runtime docker
workstation lab test rag-pipeline qdrant-outage --runtime docker
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
  `emptyDir`, not a PVC).
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

## 7. Production

Never deploy from lab or dev-service state directly. Package a template's own
`.devcontainer/Dockerfile` as the production image base (swap the dev
`postCreateCommand` install for `pip install .`), point `OLLAMA_BASE_URL` /
`QDRANT_URL` at real production endpoints via environment variables, and translate
whatever the relevant lab proved (retrieval latency/quality bounds, outage/failover
behavior) into reviewed Terraform/Helm/Ansible — by hand, same as every other lab
in this repo.
