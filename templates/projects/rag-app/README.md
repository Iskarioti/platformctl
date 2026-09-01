# __PROJECT_NAME__

Governed RAG (retrieval-augmented generation) service created by platformctl.

## Prerequisites

Both the shared model runtime and the vector database dev-service need to be running:
```bash
workstation models up
workstation models pull nomic-embed-text
workstation models pull gemma3:4b
workstation services up qdrant
```

Copy `~/.config/workstation/services/qdrant.env`'s `QDRANT_API_KEY` value into this
project's own (gitignored) `.env` - see `.env.example`.

Optionally, for LLM call tracing: `workstation services up langfuse`, then copy
`~/.config/workstation/services/langfuse.env`'s `LANGFUSE_INIT_PROJECT_PUBLIC_KEY`/
`_SECRET_KEY` into `.env` as `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY`. Leave them
blank to run without Langfuse - the app works either way.

## Develop

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

## Test

```bash
pytest
```

Try it end to end:
```bash
curl -X POST 'http://localhost:8000/ingest?text=Platformctl is a workstation-as-code repo.'
curl -X POST 'http://localhost:8000/query?question=What is platformctl?'
```

## Architecture validation before production

Before committing to a production RAG design, use `labs/ai/rag-pipeline` (a
`workstation lab`) to validate retrieval quality, latency, and failure modes under
both Docker and Kubernetes - see `docs/labs.md`'s philosophy: production is never
deployed directly from lab state, only proven patterns translated into reviewed
production IaC.

## Deploy

Package this same `.devcontainer/Dockerfile` as the production image base
(swap the dev install for `pip install .`), and point `OLLAMA_BASE_URL`/`QDRANT_URL`
at your real production model-serving/vector-database endpoints via environment
variables - never hardcode them.
