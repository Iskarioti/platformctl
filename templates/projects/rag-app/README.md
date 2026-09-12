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

## Quality evaluation against a real Langfuse dataset

`labs/ai/rag-pipeline`'s `quality` test (below) validates the *pattern* in a
disposable lab. `scripts/eval_dataset.py` runs the same golden-Q&A/LLM-judge
idea against *this app's own code path* as a real Langfuse dataset
experiment - closing a real gap: Langfuse traces every call already, but
nothing ran its dataset/scoring features against them:

```bash
python scripts/eval_dataset.py
```

Requires `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` set (see
"Prerequisites" above - this one doesn't work with Langfuse unset, unlike
the app itself). Creates/reuses a `rag-golden-qa` dataset, runs each
question through real retrieval + generation, scores each answer with an
LLM judge (`gemma3:4b` - `gemma3:1b` was confirmed too weak a judge in the
lab test below), and prints a link to the full run in the Langfuse UI.

## Architecture validation before production

Before committing to a production RAG design, use `labs/ai/rag-pipeline` (a
`workstation lab`) to validate retrieval quality, latency, and failure modes under
both Docker and Kubernetes - see `docs/labs.md`'s philosophy: production is never
deployed directly from lab state, only proven patterns translated into reviewed
production IaC.

## Threat model (OWASP LLM Top 10, applied to RAG)

- **Indirect prompt injection via retrieved content (LLM01)** - this
  template's own `/ingest` endpoint is the concrete example: anything
  ingested becomes context a future `/query` call feeds straight into the
  model's prompt. Whoever can call `/ingest` can plant instructions the
  model later treats as trusted context, not user-supplied text - the
  retrieved chunk itself becomes an injection vector. Restrict who/what can
  ingest (authn on `/ingest`, or ingest only from a reviewed pipeline, not
  an open endpoint) before this leaves prototype stage. Set
  `GUARDRAILS_ENABLED=true` (see `.env.example`, `app/guardrails.py`) to
  have `/query` flag known injection phrases found in retrieved
  content in its response (`retrievedContentFlags`) - a real, working
  starting signal, not a substitute for the access-control fix above.
- **Sensitive information disclosure (LLM02)** - anything embedded into
  Qdrant is retrievable by anyone who can query this API (or Qdrant
  directly, if it's ever exposed beyond `platform-dev`) with a similar
  enough question. Don't ingest anything a caller of `/query` shouldn't
  eventually be able to read back out, even indirectly.
  `GUARDRAILS_ENABLED=true` also redacts obvious emails/phone numbers on
  both `/ingest` and `/query`'s answer - a basic net, not a substitute for
  not ingesting sensitive data in the first place.
- **Training/knowledge-base data poisoning (LLM03/LLM04-adjacent)** - same
  root cause as the injection point above: an unvalidated `/ingest` is a
  poisoning vector for the retrieval corpus itself, not just one response.
- **Model denial of service (LLM04)** - `/query` triggers a real embedding
  call plus a real generation call per request; rate-limit or authenticate
  it the same as any endpoint that triggers non-trivial backend work,
  before it's reachable beyond `platform-dev`.
- **Overreliance (LLM09)** - retrieval improves grounding, it doesn't
  guarantee correctness. `labs/ai/rag-pipeline`'s `quality` test (a golden
  Q&A set graded by an LLM judge, gated on a threshold - see
  `docs/ai-workstation.md`) is the pattern to extend with your own domain's
  golden set before trusting answers in production.

## Deploy

Package this same `.devcontainer/Dockerfile` as the production image base
(swap the dev install for `pip install .`), and point `OLLAMA_BASE_URL`/`QDRANT_URL`
at your real production model-serving/vector-database endpoints via environment
variables - never hardcode them.
