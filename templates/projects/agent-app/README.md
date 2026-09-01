# __PROJECT_NAME__

Governed agentic-architecture service ("AgentOS"-style) created by platformctl, built
on [LangGraph](https://langchain-ai.github.io/langgraph/).

## Prerequisites

```bash
workstation models up
workstation models pull gemma3:4b
```

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

## Architecture validation before production

Before committing to a production multi-agent design, use `labs/ai/agent-mesh` (a
`workstation lab`) to validate orchestration resilience and scaling under Kubernetes
(k3d) - see `docs/labs.md`'s philosophy: production is never deployed directly from
lab state, only proven patterns translated into reviewed production IaC.

## Deploy

Package this same `.devcontainer/Dockerfile` as the production image base (swap the
dev install for `pip install .`), and point `OLLAMA_BASE_URL` at your real production
model-serving endpoint via an environment variable - never hardcode it.
