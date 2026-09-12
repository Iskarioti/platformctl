# __PROJECT_NAME__

Governed Python research environment created by platformctl.

For a LaTeX/Quarto paper (not a Python data/notebook project), use the
`research-paper` template instead.

## GPU variant

`.devcontainer/gpu/` is an opt-in second Dev Container configuration for
local model training/inference - same base image, plus a CUDA-enabled
PyTorch build (`torch` via `--index-url
https://download.pytorch.org/whl/cu126`) installed alongside
`requirements-dev.txt` in `postCreateCommand`. Requires an NVIDIA driver and
the [NVIDIA Container
Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)
on the *host* - `hostRequirements.gpu` and `runArgs: ["--gpus=all"]` do
nothing without those installed first. In VS Code, `Dev Containers: Reopen
in Container` prompts to choose a configuration when more than one exists
under `.devcontainer/`; pick "gpu". See `templates/projects/ai/README.md`'s
GPU section for the same mechanism verified end-to-end (image builds,
`import torch` succeeds) - actual GPU passthrough needs a real NVIDIA
machine to verify, untested here for that reason alone.

## Data versioning

`.dvc/config` is already scaffolded, pre-pointed at the shared `garage`
dev-service under a project-specific prefix - uncomment `dvc[s3]` in
`requirements-dev.txt`, set your local credentials (`dvc remote modify
--local ...`), and `dvc add`/`dvc push` - no `dvc init`/`dvc remote add` step
needed first. See `docs/research-computing.md` "Data versioning" for the
exact commands. Optional, not a forced dependency of this template - the
scaffolded config is inert until `dvc` is actually installed and run.

## Reference management

[Zotero](https://www.zotero.org) is GUI-only (no official CLI) - if you want
scripted access to your library from notebooks/scripts, add
[`pyzotero`](https://pyzotero.readthedocs.io) (or
[`pyzotero-cli`](https://pypi.org/project/pyzotero-cli/) for shell scripting)
to `requirements-dev.txt` yourself; it's optional, not a forced dependency
of this template.
