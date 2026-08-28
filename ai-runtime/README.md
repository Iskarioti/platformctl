# Local AI Runtime

This is a shared model runtime, not a project Dev Container.

Start:
```bash
task up
```

Pull default Gemma lab model:
```bash
task gemma4b
```

Run:
```bash
task run4b
```

Test API:
```bash
task test4b
```

Projects on the external Docker network `ai-runtime` call:
```text
http://ollama:11434
```

The API is also bound to WSL localhost:
```text
http://127.0.0.1:11434
```

Model weights live in the Docker volume `ollama-models`, not project repositories.
