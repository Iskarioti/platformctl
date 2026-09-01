# Local AI Runtime

This is a shared model runtime, not a project Dev Container. Managed via the
`workstation` CLI (`scripts/posix/models.sh` / `scripts/common/models.ps1`), not a
standalone tool - see `workstation models` for the full command list.

Start:
```bash
workstation models up
```

Pull default Gemma lab model:
```bash
workstation models pull gemma3:4b
```

Run:
```bash
workstation models run gemma3:4b
```

Check status (containers + reachable models):
```bash
workstation models status
```

Projects on the external Docker network `ai-runtime` **or** `platform-dev` (the same
network dev-services like `redis`/`qdrant` use - join it once via
`"runArgs": ["--network=platform-dev"]` in a project's `devcontainer.json` to reach
both model serving and dev-services with no extra wiring) call:
```text
http://ollama:11434
```

The API is also bound to WSL localhost:
```text
http://127.0.0.1:11434
```

Model weights live in the Docker volume `ollama-models`, not project repositories.
The image version is pinned in `versions.env` - never `:latest`, matching every
other piece of pinned infrastructure in this repo.

On a memory-constrained laptop, switch to the `ai-lab` WSL profile
(`wsl/profiles/ai-lab.wslconfig`, more RAM/swap) before pulling/running larger models:
```powershell
.\windows\25-set-wsl-profile.ps1 -Profile ai-lab
```
