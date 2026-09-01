# qdrant

This directory is the canonical configuration package for the `qdrant` local
development service - a shared vector database for RAG development
(`templates/projects/rag-app`, `templates/projects/agent-app`).

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults (REST + gRPC ports).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/` — service-specific configuration when required.

Runtime secrets (the API key), when needed, are generated outside Git under:
`~/.config/workstation/services/qdrant.env`.

From a project Dev Container already joined to the `platform-dev` network
(`"runArgs": ["--network=platform-dev"]`), reach it at `dev-qdrant:6333` (REST) or
`dev-qdrant:6334` (gRPC) - the same pattern used to reach `redis`/`ollama`.
