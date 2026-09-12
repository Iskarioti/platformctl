# __PROJECT_NAME__

Governed AI/ML data-science service created by platformctl - classical ML and data
work (FastAPI, numpy, pandas, scikit-learn, OpenTelemetry), not LLM-specific.

For LLM/agentic work, use one of the other governed AI templates instead:

- `rag-app` - retrieval-augmented generation service (Qdrant + local model runtime)
- `agent-app` - LangGraph-based agentic service
- `mcp-server` - Model Context Protocol server

## Getting started

```bash
pip install -r requirements-dev.txt
ruff check .
pytest -q
```

Runtime dependencies (FastAPI, numpy, pandas, scikit-learn, OpenTelemetry) are
installed in the Dev Container image (`.devcontainer/Dockerfile`), not via
`requirements.txt` - open this project in the Dev Container to run the service
itself.
