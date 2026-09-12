# __PROJECT_NAME__

Governed agentic-architecture service ("AgentOS"-style) created by platformctl, built
on [LangGraph](https://langchain-ai.github.io/langgraph/).

## Prerequisites

```bash
workstation models up
workstation models pull gemma3:4b
```

Optionally, for LLM call tracing: `workstation services up langfuse`, then copy
`~/.config/workstation/services/langfuse.env`'s `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`/
`_SECRET_KEY` into this project's own (gitignored) `.env` as `LANGFUSE_PUBLIC_KEY`/
`LANGFUSE_SECRET_KEY` - see `.env.example`. Leave them blank to run without
Langfuse - the app works either way.

## Develop

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

`app/main.py` scaffolds the smallest real LangGraph graph (one node, `START -> respond
-> END`) - add more nodes/edges as your agent's actual logic grows. `graph.invoke(...)`
is the extension point.

## Test

```bash
pytest
```
`tests/test_health.py` only exercises `/health` (no live model needed) so CI stays
fast and self-contained. Test `/invoke` manually against a running `workstation
models up` runtime:
```bash
curl -X POST 'http://localhost:8000/invoke?question=Say hello in five words.'
```

## Quality evaluation against a real Langfuse dataset

`scripts/eval_dataset.py` runs a golden question set through this app's own
`graph.invoke` as a real Langfuse dataset experiment - Langfuse traces every
call already, but nothing ran its dataset/scoring features against them
until now:

```bash
python scripts/eval_dataset.py
```

Requires `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` set (see
"Prerequisites" above - this one doesn't work with Langfuse unset). Creates/
reuses an `agent-golden-qa` dataset, scores each answer with an LLM judge
(`gemma3:4b` - `gemma3:1b` was confirmed too weak a judge in
`labs/ai/rag-pipeline`'s own quality test), and prints a link to the full
run in the Langfuse UI.

## Architecture validation before production

Before committing to a production multi-agent design, use `labs/ai/agent-mesh` (a
`workstation lab`) to validate orchestration resilience and scaling under Kubernetes
(k3d) - see `docs/labs.md`'s philosophy: production is never deployed directly from
lab state, only proven patterns translated into reviewed production IaC.

## Threat model (OWASP LLM Top 10, applied to agentic graphs)

- **Excessive agency (LLM06)** - the real risk as this graph grows past its
  scaffolded single `respond` node. Every node that can call a tool, another
  service, or take any action beyond generating text needs its own narrowest
  possible permission scope - a multi-step LangGraph agent that's been
  steered off-course keeps executing whatever the graph lets its current
  node do, node after node, with no human in the loop unless you add one.
  Put an explicit approval/checkpoint step before any node with a
  consequential side effect (spending money, sending something externally,
  modifying data).
- **Insecure output handling (LLM02-adjacent)** - if any future node's
  output gets rendered as HTML, executed as code, or used to construct a
  command/query, treat it as untrusted input at that boundary, same as any
  other generated text - never assume a model's output is safe because the
  prompt asked for something safe.
- **Indirect prompt injection (LLM01)** - the same risk `rag-app` documents
  applies here too, the moment this agent reads content it didn't generate
  itself (a tool's return value, a fetched page, another agent's message) -
  that content can carry instructions the graph then follows. Set
  `GUARDRAILS_ENABLED=true` (see `.env.example`, `app/guardrails.py`) to
  have `/invoke` flag known injection phrases found in its *input* in the
  response (`inputFlags`) - extend this to also scan a tool's return value
  once this graph has one; a fixed phrase list is a starting signal, not a
  substitute for the access-control fix above.
- **Model denial of service (LLM04)** - a multi-node graph can call the
  model multiple times per `/invoke`; an adversarial or just malformed input
  that causes the graph to loop (a common LangGraph failure mode without an
  explicit recursion/step limit) multiplies that cost. Set LangGraph's
  `recursion_limit` deliberately once the graph has more than one node.

## Deploy

Package this same `.devcontainer/Dockerfile` as the production image base (swap the
dev install for `pip install .`), and point `OLLAMA_BASE_URL` at your real production
model-serving endpoint via an environment variable - never hardcode it.
