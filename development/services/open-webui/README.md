# open-webui

This directory is the canonical configuration package for the `open-webui` local
development service - a self-hosted chat UI for the shared `ai-runtime` Ollama
runtime, filling the "prompt engineering interface" role in the workstation's AI
architecture (see `docs/ai-workstation.md`).

Tracked configuration:
- `service.json` — catalog metadata and dependencies.
- `versions.env` — pinned image/version.
- `defaults.env` — non-secret runtime defaults (host port).
- `.env.example` — required secret/runtime variable documentation.
- `compose.yaml` — service topology.
- `config/` — service-specific configuration when required.

Runtime secrets (the session signing key), when needed, are generated outside Git
under: `~/.config/workstation/services/open-webui.env`.

Requires `workstation models up` first (it connects to `ollama:11434` over the
shared `platform-dev` network - the same network `ollama` joins so any dev-service
or project container can reach it). Open at `http://127.0.0.1:8081` and create the
first account on first visit - that account becomes the local admin.
