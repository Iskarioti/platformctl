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

## GPU variant

`.devcontainer/gpu/` is an opt-in second Dev Container configuration - same
base image and packages, plus a CUDA-enabled PyTorch build
(`torch==2.14.0+cu126`). Requires an NVIDIA driver and the [NVIDIA Container
Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
on the *host* - `hostRequirements.gpu` and `runArgs: ["--gpus=all"]` in its
`devcontainer.json` do nothing without those installed first. In VS Code,
`Dev Containers: Reopen in Container` prompts to choose a configuration when
more than one exists under `.devcontainer/`; pick "gpu". Build itself was
verified on this repo's own CI-equivalent machine (no GPU present) - the
image builds and `import torch` succeeds, reporting `torch.version.cuda ==
'12.6'` and (correctly, on a GPU-less host) `torch.cuda.is_available() ==
False`. Actual GPU passthrough (`torch.cuda.is_available() == True`) needs a
real machine with an NVIDIA GPU to verify - untested here for that reason,
not because the mechanism is unfinished.
