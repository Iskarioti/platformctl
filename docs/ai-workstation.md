# AI/ML Workstation

A governed, local-first lifecycle for testing models, building MCP servers, and
developing RAG/agentic architectures before anything reaches production. It follows
this repo's existing three-tier mechanism instead of inventing a fourth one:

- **dev-service** (stable, shared, always-on infra) — `ai-runtime` (Ollama) and the
  `qdrant` dev-service.
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

## 3. Project templates

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

## 4. Architecture validation before production

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

Kubernetes runtime manifests exist for both labs (Deployments/Services behind
`kubectl apply -k`, matching `redis-cluster`'s established layout) but require
`workstation lab toolchain install` first. `agent-mesh` additionally needs its
`prepare-kubernetes.sh` hook (invoked automatically by `lab up --runtime
kubernetes`) to build its app image and `k3d image import` it into the
`platform-labs` cluster, since it isn't published to a registry.

## 5. Production

Never deploy from lab or dev-service state directly. Package a template's own
`.devcontainer/Dockerfile` as the production image base (swap the dev
`postCreateCommand` install for `pip install .`), point `OLLAMA_BASE_URL` /
`QDRANT_URL` at real production endpoints via environment variables, and translate
whatever the relevant lab proved (retrieval latency/quality bounds, outage/failover
behavior) into reviewed Terraform/Helm/Ansible — by hand, same as every other lab
in this repo.
