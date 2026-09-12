# Capacity Planning

A rough resource budget for this workstation's dev-services, labs, and local
models - real numbers pulled from what's actually declared/observed, not
estimates. This complements `workstation doctor`'s disk/memory threshold
checks (which tell you when you're close to a problem) with a sense of
*why* - what's actually consuming the budget, and by how much, before you
get there.

## Dev-service memory budget, by profile

Every dev-service declares a real `mem_limit` in its own `compose.yaml`
(`development/services/*/compose.yaml`) - Docker enforces it, a runaway
container gets OOM-killed rather than starving the rest of the machine.
Profiles (`development/catalog.json`) sum like this:

| Profile | Services | Memory ceiling |
|---|---|---|
| `core` | postgres, redis | ~1.5 GB |
| `data` | postgres, pgbouncer, mongodb | ~1.9 GB |
| `messaging` | kafka, rabbitmq | ~2.3 GB |
| `search` | opensearch | 2 GB |
| `integration` | minio, mailpit | ~0.6 GB |
| `ui` | dev-dashboard, pgadmin, redisinsight, kafbat-ui, opensearch-dashboards | ~2.75 GB |
| `observability` | otel-collector, prometheus, loki, tempo, grafana, cadvisor, node-exporter | ~2.75 GB |
| `ai` | qdrant, open-webui, langfuse, mlflow | ~4.5 GB |
| `all` (every service, once) | everything above, deduplicated | **~18.75 GB** |

`all` is the true worst case - every dev-service running at once, each at
its declared ceiling. In practice `workstation services up <profile>` starts
only what a given day's work needs, and `workstation services down` releases
it; `all` is the number to check against before assuming a machine with,
say, 16 GB of RAM can comfortably run the entire catalog simultaneously (it
can't - that's the point of profiles, not a flaw in this table).

## Labs

Labs generally run *outside* this budget (a separate profile, brought up/
torn down independently) and mostly do **not** set an explicit `mem_limit`
today - `labs/kafka/kraft-3` is the one exception (`1024m` per broker, 3
brokers). An unbounded lab container can consume as much host memory as the
image needs; that's an accepted tradeoff for disposable, short-lived
architecture-validation environments (see `docs/labs.md`), not something
this doc treats as fixed - if a specific lab becomes a habitual background
resource hog, give it a real `mem_limit` the same way `kraft-3` already has
one, rather than budgeting around it here.

## Local models (Ollama)

Model weights are the largest single line item on this machine, and they're
shared across every consumer (`workstation models`, `rag-app`, `agent-app`,
labs) via one runtime - pulling once, not once per consumer:

| Model | Size on disk (observed) | Typical use |
|---|---|---|
| `nomic-embed-text` | ~274 MB | embeddings (RAG retrieval) |
| `gemma3:1b` | ~815 MB | fast generation, or a lab's smoke-test model |
| `gemma3:4b` | ~3.3 GB | default chat/generation model for templates and labs |

Running inference itself needs headroom beyond the weights on disk (KV
cache, context window) - a rough rule of thumb is 1.5-2x the model's disk
size in free RAM while it's actively generating, more with a large context
window or several concurrent requests.

## Disk

`workstation doctor`'s disk check warns under 10% free on the drive backing
this repo - that number is deliberately generic (any drive, any workload).
The two largest disk consumers in practice are Docker volumes (dev-service
data - `docker volume ls`, prefixed `platform-*`) and pulled Ollama model
weights (`~/.ollama` inside the `ai-runtime` container, or wherever
`workstation models` mounts it) - check those two first if disk pressure
shows up, before assuming it's this repo's own files.

## Using this doc

This is a planning reference, not an enforced budget - nothing here blocks
`services up` from starting more than a machine can handle. If that becomes
a real problem, the natural extension is a `workstation doctor` check that
sums the `mem_limit` of every currently *requested* profile against free
system RAM before starting it, not just after (today's `workstation catalog
costs` and the disk/memory checks already in `doctor` are the building
blocks for that, not yet wired together into a pre-flight check).
