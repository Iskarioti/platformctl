# Daily Workflow v2

## Normal morning

Windows:
- open Outlook/Teams/Edge only as needed
- use ChatGPT/Claude for research, architecture, incident reasoning and writing

WSL:
```bash
wsl
platformctl doctor
docker ps
```

Do not start project containers or Ollama until needed.

## Light development

```bash
cd ~/src/company/<repo>
git fetch --all --prune
git switch main
git pull --ff-only
git switch -c feature/<ticket>-<description>
code .
```

Reopen in Dev Container.

Inside Dev Container:
```bash
task bootstrap
task agent:versions

# Codex
codex

# or Claude Code
claude
```

First login occurs inside the trusted Dev Container. WSL-hosted `~/.codex` and `~/.claude`
are mounted so login state survives container rebuilds.

Use the agent to understand/implement, then:
```bash
task lint
task type
task test
task security
task verify
git diff
```

Do Git push from WSL if you do not intentionally forward Git credentials into the container:
```bash
exit
git status
git push -u origin HEAD
```

## Local Gemma lab

Start shared runtime:
```bash
cd ~/src/tooling/system-platform-architect-workstation-v2/ai-runtime
task up
task gemma4b
task test4b
```

Inside any trusted project Dev Container:
```bash
task ai:status
task ai:test
```

Stop when not required:
```bash
cd ~/src/tooling/system-platform-architect-workstation-v2/ai-runtime
task stop
```

### Larger Gemma experiment

Switch Windows/WSL resource profile:
```powershell
.\windows\25-set-wsl-profile.ps1 -Profile ai-lab
```

Then in WSL:
```bash
cd ai-runtime
task up
task gemma12b
```

Close unnecessary Windows applications while benchmarking.

After testing:
```bash
task stop
```

Return to default:
```powershell
.\windows\25-set-wsl-profile.ps1 -Profile default
```

## Incident workflow

Run diagnostics directly from WSL, not a Dev Container:
```bash
platformctl net diagnose <host> --port <port>
platformctl incident collect --host <host> --port <port>
```

Use ChatGPT/Claude to analyze a sanitized evidence package. Do not paste secrets, private keys or restricted data into an unapproved AI service.

## NPU lab

Native Windows only:
```powershell
.\windows\50-npu-lab.ps1
```

Use this for OpenVINO/NPU benchmarking. Keep it separate from normal Dev Container development.

## End of project work

Inside Dev Container:
```bash
task verify
```

From WSL:
```bash
git diff
git status
git push
```

Stop project:
```bash
docker compose down
```

Check Docker usage periodically:
```bash
docker system df
```
