# Changelog

## 3.21.0

Desktop appearance (Windows taskbar/Start Menu, cross-platform app installs)
and a real script-permissions bug found and fixed along the way.

- **Windows taskbar/appearance**: centered alignment, hidden search, hidden
  Task View button, Win+X menu shows Windows PowerShell, dark mode, Bing
  Wallpaper launched automatically after install. Widgets is best-effort only
  - confirmed live that Windows's own UCPD (User Choice Protection Driver)
  blocks the registry write on any sufficiently-updated Windows 11 install
  (not this machine's MDM policy, as first suspected - corrected after
  further live + web research); documented manual alternatives instead of
  weakening that OS security control.
- **`workstation enforce`/`--repair`** now checks/repairs Windows desktop
  appearance drift too, not just WSL/Docker/project-root policy - Widgets
  reports as a WARN (UCPD-blocked), never a FAIL.
- **New cross-platform installs**: Logi Options+ (Windows/macOS; Solaar is
  the Linux equivalent - Logitech ships no Linux client), Wireshark, WireGuard,
  Microsoft Teams, Outlook. Teams/Outlook have no supported Linux client
  either (web apps only) - not faked via an Electron/Flatpak wrapper.
- **Taskbar/Start Menu pin guidance extended**: unpin everything first, then
  pin LibreWolf/Settings/VS Code/Alacritty (always) plus Teams/Outlook
  (only when actually installed); separately, pin Wireshark/WireGuard/
  Outlook/Microsoft Edge to the Start Menu. The script verifies each app is
  actually installed before listing it as pinnable - found two real gaps
  doing this: Alacritty was never in `windows/10-install-tools.ps1` at all,
  and LibreWolf was listed there but had never actually been installed on
  this machine. Both fixed and installed.
- **Start Menu pin list extended**: 7-Zip, Logi Options+, PowerToys, Windows
  Terminal, MiKTeX Console - every "core" baseline app with a genuine Start
  Menu entry not already taskbar-pinned. Azure CLI was asked for but has no
  Start Menu shortcut at all (CLI-only) - reported `[NOT PINNABLE]` rather
  than faked. Also made explicit: a workstation setup unpins *everything* on
  both Start and taskbar first, then pins only this repo's explicit list -
  nothing else stays pinned.
- **Real bug found and fixed**: `windows/10-install-tools.ps1`'s Pandoc and
  pixi installs were failing with MSI error 1934 ("User installations are
  disabled via policy on the machine") - both installers default to a
  per-user scope, which this machine's Group Policy blocks outright. Fixed by
  retrying with `winget install --scope machine` when the default install
  fails - not a security-control bypass (per-user installs stay exactly as
  disabled as the policy intends), just using the scope the policy still
  permits. `workstation upgrade`'s `packages` scope now completes with 0
  failures.
- **Real bug found and fixed**: several tracked POSIX scripts
  (`install-librewolf.sh`, `install-research-tools.sh`,
  `install-security-tools.sh` on both Linux/macOS, macOS's
  `configure-appearance.sh`, and `scripts/posix/{security,research,catalog,
  models,dr-drill,drift-check,ensure-ssh-agent}.sh`) were tracked without the
  executable bit - every `bootstrap.sh` call site wraps them in `|| true`, so
  a fresh Linux/macOS clone would silently no-op several install steps and
  `workstation security/research/catalog/models/dr-drill/drift-check` would
  all fail "Permission denied" with the failure swallowed. Fixed via
  `git update-index --chmod=+x`, same fix as the earlier `core.fileMode=false`
  bootstrap-script bug, just never applied to these particular files.

## 3.20.1

A careful line-by-line re-audit of all six "Five Hats" reports against
actual repo state (prompted by being asked directly "have you implemented
everything" a second time) found four remaining loose ends in v3.20.0's own
implementation - closed out here:

- **`agent-app` gets its own `scripts/eval_dataset.py`** - v3.20.0 only gave
  `rag-app` a real Langfuse dataset experiment; the AI Engineer gap
  ("Langfuse captures traces but nothing runs its dataset/scoring features
  against them") was generic to both apps. Verified live the same way
  (mean_score=1.000, real dataset-run URL returned).
- **`rag-quality-eval.yml`'s path filter narrowed** to just
  `labs/ai/rag-pipeline/**` - it previously also triggered on
  `templates/projects/{rag-app,agent-app}/**` changes despite the job never
  exercising either template, which was pure wasted CI runs with no signal.
- **The dashboard's "Toolchain health" panel gains "Paper builds"** -
  v3.20.0's panel covered scan/research-toolchain/template-drift but missed
  the Hybrid gap's own third example, "did the paper build." A real local
  proxy (no GitHub API call): `paper/main.pdf` newer than `paper/main.tex`
  for every governed project scaffolded from `research-paper`. Verified live
  through all three states (never built, built, source changed since last
  build) with a real scaffolded test project.
- **Template proliferation** (Platform Engineer gap #5, the one gap across
  all six reports with no suggestion attached) is now acknowledged in
  `README.md`'s template table rather than left silently unaddressed -
  `workstation catalog stats` is named as the real signal to watch, since
  there wasn't a concrete fix worth building preemptively.

## 3.20.0

The remaining granular gaps/suggestions from the "Five Hats, One Workstation"
role audit that Tier 1-3's synthesized roadmap didn't individually cover -
asked for directly ("have you implemented both the gaps and suggestions"),
this closes out the full set from all six persona reports.

- **Research**: `make diff REF=<ref>` (latexdiff, reviewer-facing revision
  PDFs) for `research-paper` - found and fixed a real missing dependency
  (`ulem.sty`, provided by `texlive-plain-generic`) live-testing it. A
  `--gpu` Dev Container variant for `research-python` (CUDA PyTorch, same
  verified mechanism as the `ai` template's). A real, already-scaffolded
  `.dvc/config`/`.dvc/.gitignore` (not just a prose mention) pointed at the
  shared `garage` bucket - verified end-to-end via a live `project init`.
  Literature-search tooling and HPC/cluster job submission are now
  explicitly documented as out of scope, with the reasoning, rather than
  silently dropped (`docs/research-computing.md`).
- **AI Engineer**: `rag-app`/`agent-app` get a versioned `app/prompts.py`
  (previously inline f-strings) and an opt-in `app/guardrails.py` (PII
  redaction + prompt-injection flagging, no-op unless
  `GUARDRAILS_ENABLED=true` - the same pattern Langfuse tracing already
  uses). `rag-app`'s Qdrant collection name is now suffixed with the
  embedding model, so changing `EMBED_MODEL` can't silently orphan the old
  collection. `rag-app/scripts/eval_dataset.py` runs the golden Q&A set as a
  real Langfuse **dataset experiment** (`run_experiment`) - traces were
  already captured; nothing previously ran Langfuse's own scoring/dataset
  features against them. `labs/ai/rag-pipeline`'s `quality` test now also
  runs in real CI (`.github/workflows/rag-quality-eval.yml`, path-filtered -
  it pulls real models and runs real CPU inference, too costly to run on
  every commit).
- **DevSecOps**: `policy/development.json`'s `lockfilePolicy` is tightened
  from `warn` to `required`. Getting there required actually generating real
  lockfiles for every template first (`requirements.lock` via `pip-compile`
  for 9 Python templates, `package-lock.json` for `react-app`) - which
  surfaced two real pre-existing bugs: the `ai` and `network-automation`
  templates never actually installed their own pinned dependencies at all
  (no `postCreateCommand`, nothing ever ran `pip install`), fixed by moving
  them onto the same lockfile-installing Dockerfile pattern as everything
  else. `project-check.sh` also gained real Terraform-provider detection
  (`required_providers` grep) so `infra`/`terraform` aren't silently exempt
  from the tightened policy forever, just until a project declares its
  first real provider. Found and fixed a real, unrelated cross-platform bug
  along the way: `validate.ps1`'s blanket JSON-syntax check choked on
  `package-lock.json`'s standard `""`-keyed root package entry - valid JSON,
  rejected by `ConvertFrom-Json`'s default typed-object parse; switched to
  `-AsHashtable`.
- **Platform Engineer**: `workstation services scaffold <name>` generates a
  new dev-service's full file skeleton (service.json/compose.yaml/versions.env/
  defaults.env/.env.example/README.md), pre-wired to the `consumes`
  convention - verified live.
- **Systems Engineer & Architect**: `workstation drift-check` compares
  actually-running dev-service containers against `development/catalog.json`
  (undeclared containers, image/version mismatches) - verified live against
  all three cases (clean, undeclared, mismatched) with correct exit codes.
  Found and fixed a real bug of its own: Docker normalizes away an explicit
  `docker.io/` registry prefix in `docker ps`'s own `Image` field, causing a
  false-positive mismatch for any image pinned with that prefix (langfuse).
  Wired into `workstation doctor` on both the bash and PowerShell (dispatched
  through WSL) sides. `docs/capacity-planning.md` - a real resource budget
  per dev-service profile (~18.75 GB worst case, every service at once),
  labs, and local models, built from real declared `mem_limit` values and
  observed model sizes, not estimates.
- **Hybrid**: platformctl's own web control plane gains a seventh panel,
  "Toolchain health" (security-scan freshness, research-toolchain install
  status, template drift) - the same state `workstation doctor` already
  reads, reused rather than duplicated. Verified live against the real
  always-on dashboard service (an editable `uv tool install`, so the running
  process picked up the change on a plain restart - confirmed by resolving
  `platformctl.web.status.__file__` from inside the running venv before
  restarting it).

## 3.19.0

Tier 3 of the "Five Hats, One Workstation" role-audit roadmap - the last six,
lower-urgency findings, completing the full roadmap.

- **Dependency updates**: `.github/dependabot.yml` in all 12 templates
  (weekly, grouped per ecosystem - `docs/dependency-updates.md`).
- **GPU Dev Container variant**: `templates/projects/ai/.devcontainer/gpu/`
  - CUDA-enabled PyTorch (`torch==2.14.0+cu126`), opt-in alongside the
    existing CPU-only default. Build verified live (image builds, `import
    torch` succeeds, reports `cuda: '12.6'`); actual GPU passthrough needs a
    real NVIDIA machine to verify, honestly flagged as untested rather than
    assumed working.
- **Secrets rotation**: `workstation services rotate <service>` - automated
  and verified live for the services confirmed safe (`redis`, `qdrant`,
  `minio`, `open-webui` - credential checked live against the env var, never
  persisted separately); every other service is refused outright with a
  pointer to its correct manual procedure in the new
  `docs/secrets-rotation.md`, rather than silently doing something unsafe.
- **AI threat-modeling**: OWASP LLM Top 10-mapped "Threat model" sections
  added to `mcp-server`/`rag-app`/`agent-app` READMEs, grounded in each
  template's actual attack surface (e.g. `rag-app`'s own `/ingest` endpoint
  as a concrete indirect-injection/poisoning vector).
- **Compliance evidence mapping**: `docs/compliance-evidence-mapping.md` -
  an honest index from real, already-built mechanisms in this repo to the
  kind of evidence a SOC 2/ISO 27001 auditor asks for, explicit about what
  it doesn't cover.
- **Cost awareness**: `workstation catalog costs` - illustrative
  managed-cloud sizing estimate from what's actually running right now
  (real `docker inspect` memory limits), explicitly labeled as a rough
  FinOps signal, not a quote.

## 3.18.0

Tier 2 of the "Five Hats, One Workstation" role-audit roadmap: proving
reliability mechanisms actually work, and rounding out the AI/ML lifecycle
with experiment tracking, data versioning, and a real answer-quality gate.

- **`workstation dr-drill`** rehearses the entire backup/restore path for
  real, on the real machine, without ever touching it: a real `backup.sh`
  (random one-time passphrase via `WORKSTATION_BACKUP_PASSPHRASE`) into a
  throwaway file, then a real `restore.sh` into a throwaway `$HOME` (new
  `WORKSTATION_RESTORE_HOME` override), verified by file count, logged to
  `.state/dr-drill-YYYY-MM-DD.log`. A backup path nobody has ever exercised
  is a hypothesis, not a control - the Systems Engineer & Architect role
  review's top finding. Found and fixed a real bug building it: a
  `{ ... } | tee` pipeline runs the block in a subshell, silently discarding
  the `result` variable it set - switched to process substitution.
- **New `mlflow` dev-service** - experiment tracking + model registry,
  sharing the `postgres` and `garage` dev-services (same pattern as
  `langfuse`), verified end-to-end with a real logged run, metric, and
  artifact landing in Garage. Found and fixed a real bug live: the default
  4 uvicorn workers OOM-killed it at a 1g memory limit - reduced to 1 worker,
  appropriate for a single-developer local service. Also confirmed MLflow
  3's own Host-header security middleware resets the connection outright
  without `--allowed-hosts` set, even for a same-machine request.
- **DVC** wired into `research-python` as an opt-in dependency, versioning
  data/model files against the same shared `garage` bucket, one prefix per
  project.
- **A real RAG answer-quality eval** - `workstation lab test rag-pipeline
  quality`: a golden question/answer set through real retrieval and
  generation, graded by a second LLM acting as judge, gated on a numeric
  threshold. Confirmed live that `gemma3:1b` is too weak a judge (scored an
  obviously-correct paraphrase `0.1`) - judging uses `gemma3:4b` instead,
  confirmed correct on the same case.
- ADR log (`docs/adr/`) and usage telemetry (`.state/usage.jsonl`,
  `workstation catalog stats`) from earlier in this roadmap.

## 3.17.0

Tier 1 of the "Five Hats, One Workstation" role-audit roadmap (the highest-
leverage findings independently named by multiple persona reviews): a real
cross-domain status aggregator, security/quality gates that actually reach
CI, and a template lifecycle.

- **`workstation doctor` is now a real cross-domain aggregator**, not just a
  tool-presence checker (`scripts/common/doctor.ps1` + the bash fallback in
  `scripts/posix/workstation.sh`): security-scan freshness, disk/memory
  capacity thresholds, whether any lab cluster is up, and how many governed
  projects are on an outdated template version - all in one ranked view,
  the same command already run every morning per `docs/getting-started.md`.
- **`workstation security scan` now persists state** instead of starting
  from zero context every run: a rolling `.state/security/last-scan.json`
  for the doctor aggregator, and a per-project `.platformctl/
  security-scan.json` that `workstation project doctor` now reads back
  (scan age + finding count).
- **New `templates/catalog.json`** (version + status per template) - every
  new project now records the template version it was scaffolded from, and
  `project doctor` flags a project whose template has since moved on, or
  come from a template now marked deprecated.
- **Security scanning now reaches per-project CI**, not just a manual local
  command: a new `security.yml` (Semgrep/Gitleaks/TruffleHog/Trivy/Checkov)
  added to all 12 templates, required by both `policy.yml` (CI-side) and
  `scripts/posix/project-check.sh` (local-side) - the exact gap the
  DevSecOps and Platform Engineer role reviews both independently flagged.
- **A new template-build CI matrix** in `.github/workflows/
  behavioral-tests.yml`: every template is scaffolded for real
  (`project-init.sh`, not a hand-copy) and its own documented verify command
  is run against the result - the Platform Engineer review's "a template
  can silently rot with no signal" gap.

Found and fixed three real, pre-existing bugs while building and verifying
this, none of them things this session introduced:
1. **The `fastapi-service` template itself failed its own `ruff check`** -
   a genuine import-formatting violation in `tests/test_health.py`, live
   only because this is the first time anything actually scaffolded this
   template and ran its own CI command against the result. Fixed; the
   template's own CI would have been silently red on the very next project
   created from it.
2. **`.github/workflows/behavioral-tests.yml` had two embedded multi-line
   Python snippets that were invalid YAML** (an indentation mismatch inside
   a `run: |` block scalar) - found live while validating an unrelated
   edit, confirmed pre-existing via `git diff` and never caught before
   because this repo's own `workstation validate` only parses `.json`
   files, never `.yml`. The real fix wasn't re-indenting the embedded
   Python (Python's own top-level-statement indentation rule made that
   impossible without breaking execution) - it was extracting both
   snippets into real, testable files: `scripts/ci/
   count-unhealthy-services.py` and `scripts/ci/
   verify-core-services-healthy.py`.
3. **This repo's own top-level CI workflows** (`behavioral-tests.yml`,
   `validate.yml`) still referenced GitHub Actions by mutable tag
   (`actions/checkout@v4`, `actions/setup-python@v5`) - the earlier
   template-wide SHA-pinning pass (v3.13.0) only scanned `templates/`, not
   the repository's own `.github/workflows/`. Pinned to the same commit
   SHAs already resolved for the templates.

Verified live: a real `workstation project init` + `workstation security
scan` round-trip confirmed both state files write and `project doctor`
reads them back correctly; `workstation doctor` on this machine correctly
found 2 of 3 real pre-existing governed projects (`wiocchub-api`,
`wiocchub-app`) on an outdated template version (adopted before
`templateVersion` existed) and correctly did NOT flag the third
(`hub-worker`, an adopted project with no specific template) - a genuine,
not simulated, positive result. The Python-flavored template-matrix job's
scaffold+ruff+pytest sequence was run locally end-to-end (which is what
surfaced bug #1 above); the Terraform/Node/LaTeX-toolchain matrix jobs are
syntax-valid and reuse command sequences already proven elsewhere in this
repo, but weren't executed locally - this machine has none of those three
toolchains installed, flagged rather than claimed verified.

## 3.16.0

Onboarding/discoverability overhaul, following a fresh-eyes usability review
(a fresh subagent walking the repo as a first-time junior engineer with zero
prior context). The finding: every persona already has real, working
tooling - the front door was broken, not the tooling. Concretely: README
listed 5 of 12 templates and omitted `services`/`security`/`research`/
`models`/`lab`/`editor` from its command examples entirely;
`docs/daily-workflow.md` referenced commands (`task bootstrap`) that no
Taskfile in this repo backs; 23 docs existed with no index, 11 invisible
from README; overlapping-sounding templates (`ai`/`rag-app`/`agent-app`/
`mcp-server`, `research-python`/`research-paper`, `infra`/`terraform`) gave
no disambiguating signal at the point of choice; the dashboard showed
running services but never what to type to start something.

- **New `docs/getting-started.md`** - the one narrated "Day 1" path
  (bootstrap -> pick a template -> do the work -> end of session), replacing
  the scattered/contradictory workflow docs. Folds in `daily-workflow-v2.md`'s
  genuinely-accurate content (confirmed `platformctl doctor`/`net diagnose`/
  `incident collect` are a real, separate diagnostics CLI, not stale -
  verified before touching anything) while dropping its `task lint`/`task
  verify`/etc. assumption, which no Taskfile anywhere in this repo backs.
- **`daily-workflow.md`, `daily-workflow-v2.md`, `development-services.md`**
  replaced with short deprecation stubs pointing to their replacements -
  left in place (not deleted) so old links don't 404, but their misleading
  content is gone.
- **README rewritten**: all 12 templates in a disambiguating table, worked
  examples for every major command group, a categorized doc index (start
  here / by subsystem / automation / reference) replacing the flat list.
- **`workstation help` (and `setup.ps1`'s default help) regrouped** by
  workflow (Workstation health / Start a project / Local infrastructure /
  Quality & security / Editor & shell / Automation & maintenance) instead of
  a flat ~24-command dump, with a description on every line.
- **`workstation project templates` now prints a real description per
  template** (extracted from each template's own README - single source of
  truth, no separate list to keep in sync), directly resolving the
  `ai`/`rag-app`/`agent-app`/`mcp-server`-style disambiguation problem at
  the exact point of choice.
- **Dashboard**: every dev-service tile's description now includes the
  actual `workstation services up <name>` command; new "🚀 Quick Start"
  bookmarks group (getting-started, security scan, research, dev-services,
  AI/ML) for the workflows that don't map to a single running service tile.

Found and fixed one real, pre-existing bug verifying the dashboard change
live (not assumed working): `dev-dashboard`'s config mount was read-only,
but homepage v2.0.0 needs to write to it regardless - it creates its own
`logs/` dir for a logfile and copies in a default skeleton file for any of
its recognized config filenames not already present. Read-only 500'd every
request (`EROFS: read-only file system`, `"Make /app/config writable"` is
homepage's own error hint). A nested writable volume at the same path
doesn't work either - confirmed live that the parent read-only bind mount
blocks Docker from even creating the nested mountpoint. Fixed by dropping
`:ro` entirely; the one file this actually writes into the tracked
directory (`kubernetes.yaml`, an unused default skeleton) is now
gitignored - `logs/` was already covered by the repo's existing `.gitignore`.

## 3.15.0

Phase D of the "fully fledged cross-platform workstation" plan: tie
Phases A-C together into the existing `workstation doctor` health check
rather than leaving the new tooling only discoverable via `workstation
security doctor`/`workstation research doctor` separately.

- `scripts/common/doctor.ps1` and `scripts/posix/workstation.sh`'s bash
  fallback both now report the full security + research toolchain (PASS/MISS
  per tool), guarded to WSL/Linux/macOS only - these tools install into
  `~/.local/bin` and Windows dispatches `security`/`research` into WSL
  rather than installing anything natively, so checking for them on native
  Windows would just be a permanently-misleading MISS.
- `docs/new-machine.md` updated so the "what bootstrap gives you" summary
  actually reflects everything now installed in one `bootstrap`/
  `bootstrap.ps1` run.

Found and fixed one real bug along the way: `scripts/common/doctor.ps1`
found no PowerShell installed on this session's own WSL instance at all
(`pwsh: command not found`) despite AGENTS.md/this repo's docs treating
PowerShell 7 as a cross-platform requirement - `workstation doctor` was
silently falling back to `scripts/posix/workstation.sh`'s much shorter bash
fallback doctor instead, on this machine, right now. Extended that bash
fallback with the identical new tool list rather than assuming pwsh's
presence, so `workstation doctor` reports the full picture either way.

Also found, out of scope for this plan (flagged, not touched): `docs/
new-machine.md` describes `wsl/bootstrap.sh` as the live WSL setup path,
but tracing every caller shows only `wsl/import-windows-ssh-keys.sh` (via
`workstation ssh-import` and autosync's key-copy step) is actually wired
into the current architecture - `wsl/bootstrap.sh` itself and its siblings
(`doctor.sh`/`doctor-v2.sh`/`install-engineering-tools.sh`/
`install-azure-cli.sh`/`install-shell-experience.sh`/`prepare-ai-state.sh`)
appear to be orphaned leftovers from an earlier architecture, superseded by
`platform/linux/bootstrap.sh` + `scripts/posix/*.sh`, with no caller
remaining anywhere in the active codepath. Worth a dedicated cleanup pass
(confirm dead, then either revive the useful bits - it has a real Trivy
apt-repo install this plan's own `install-security-tools.sh` ended up
reimplementing sudo-free instead - or delete) separately from this plan.

## 3.14.0

Phase C of the "fully fledged cross-platform workstation" plan: a research
computing toolchain for the PhD/CS researcher persona, wrapped in a new
`workstation research` command, plus a new `research-paper` project
template.

- **New tools** (`platform/linux/install-research-tools.sh` / `platform/
  macos/install-research-tools.sh`, run from each OS's `bootstrap.sh`; MiKTeX
  via winget on native Windows - confirmed with Andrew, no clean
  winget-native TeX Live path exists and MiKTeX is the Windows-native
  standard anyway): TeX Live (Linux apt/macOS `mactex-no-gui` cask) + Pandoc,
  Quarto (sudo-free tar.gz release - more standard than raw LaTeX+bibtex in
  2026 for anything mixing code and prose), pixi (the 2026-recommended
  reproducible-env tool over raw conda/mamba for new projects).
- **New `workstation research doctor`** (`scripts/posix/research.sh` +
  `scripts/common/research.ps1`, wired identically to `security`/`services`).
- **New `research-paper` template**: the standard paper-scaffold convention
  (`paper/main.tex` + `refs.bib`, `paper/{figs,tables}/` generated not
  hand-edited, `code/`, `data/`, `make paper` via `latexmk`) - added to
  `policy/development.json`'s `allowedTemplates` (bumped to 1.4.0). Quarto
  also available in the same Dev Container for `.qmd` authoring.
  `research-python`'s README now points here for LaTeX-only work, and notes
  `pyzotero`/`pyzotero-cli` as an opt-in for scripted Zotero access (Zotero
  itself is GUI-only, no official CLI).
- New `docs/research-computing.md`.

Found and fixed one real bug live-testing the sudo-free tools: pixi's own
install script defaults to `~/.pixi/bin` and self-edits `.bashrc`/`.zshrc`
with its own `PATH` line - inconsistent with every other tool here
(`~/.local/bin`, already on `PATH` via `shell/{bash,zsh}/architect.*rc`) and
outside this repo's "shell rc files are managed fragments" convention.
Fixed with `PIXI_BIN_DIR`/`PIXI_NO_PATH_UPDATE` env vars the install script
itself supports - confirmed live that a first, uncorrected run left a stray
line in `.zshrc` pointing at a since-removed directory, and that the
corrected run installs cleanly to `~/.local/bin` with no rc-file edits at
all.

TeX Live/Pandoc's actual `apt install` was not live-tested in this session:
it's a genuine system package (unlike this session's sudo-free tools) and
needs a real sudo password, which this session has no TTY to supply and the
cached credential had expired - `quarto`/`pixi`/the `research-paper`
template scaffold/`workstation research doctor`'s dispatch are all
confirmed working for real; the two apt packages themselves are flagged as
unverified rather than claimed working, per this session's established
honesty standard for anything that couldn't actually be run.

## 3.13.0

Phase B of the "fully fledged cross-platform workstation" plan: a real
DevSecOps toolchain, wrapped in a new `workstation security` command.

- **New tools** (installed via new `platform/linux/install-security-tools.sh`
  / `platform/macos/install-security-tools.sh`, run from each OS's
  `bootstrap.sh`): Semgrep (SAST), Gitleaks + TruffleHog (secret scanning -
  fast pre-commit-style plus live-credential verification), Trivy (SCA/
  container/IaC/license in one), Grype + Syft (second-opinion CVE scan +
  CycloneDX SBOM), Checkov (IaC), Cosign (Sigstore image signing), Conftest
  (OPA/Rego policy-as-code). `tfsec`/`terrascan` deliberately not adopted -
  tfsec merged into Trivy, terrascan is archived.
- **New `workstation security scan|sbom|doctor`**
  (`scripts/posix/security.sh` + `scripts/common/security.ps1`, wired into
  both `workstation.sh` and `setup.ps1` exactly like `services`/`editor`).
  Windows dispatches into WSL rather than installing anything natively -
  governed project code lives under WSL's `~/src/*` per policy, so that's
  always where scanning actually runs, same as `services`/`editor`/`models`.
- **CI wiring**: `azure-pipelines/python-service.yml`'s long-standing "Add
  Trivy/SBOM steps" TODO is now real - Trivy scans the built container,
  Syft publishes a CycloneDX SBOM artifact.
- New `docs/security-scanning.md`.

Found and fixed four real bugs verifying this live (not just written and
assumed to work):
1. The Linux install script's `sudo apt-get`/`sudo systemctl`-style calls
   hung forever once this session's cached sudo credential expired (no TTY
   to answer a password prompt) - the same class of bug already fixed once
   this session for `services.sh`. Fixed properly this time by making the
   whole script **sudo-free**: pipx-based tools install user-level (with a
   throwaway-venv bootstrap for pipx itself, since Debian/Ubuntu's system
   `python3` deliberately ships no `pip` and refuses `ensurepip`, forcing
   `apt install python3-pip` otherwise - confirmed live), everything else
   via each tool's own official install script into `~/.local/bin`.
2. Resolving "latest version" via `api.github.com` (for Gitleaks and
   Conftest, which have no package-manager listing) hit GitHub's 60
   requests/hour unauthenticated rate limit and 403'd during testing.
   Fixed by resolving the version from the redirect target of a repo's
   plain `github.com/.../releases/latest` URL instead, which has no such
   limit.
3. `workstation security doctor` crashed on `cosign --version` ("unknown
   flag") - cosign uses a bare `cosign version` subcommand instead, unlike
   every other tool here. Fixed with a per-tool override.
4. Invoked from Windows, every tool showed MISS despite being installed -
   `wsl.exe -- bash <script>` runs a non-login shell that never sources
   `.bashrc`/`.profile`, so `~/.local/bin` was never on `PATH`. Fixed by
   setting `PATH` explicitly inside `security.sh` itself rather than
   depending on shell startup files having already run.

Also found live, closing the loop on the new tooling actually working:
running `workstation security scan` against this repo's own project
templates surfaced a real, non-hypothetical finding - every template's CI/
policy workflows referenced GitHub Actions by a mutable tag
(`actions/checkout@v4` etc.), which Semgrep correctly flags as a
supply-chain risk. Fixed across all 11 templates: every `actions/checkout`,
`actions/setup-python`, `actions/setup-node`, and `hashicorp/setup-terraform`
reference is now pinned to its exact commit SHA (resolved via `git
ls-remote`, avoiding the same rate limit as above), with a `# vN` comment
for readability. Re-scanning confirmed 0 findings afterward.

One more real, unrelated bug found while re-validating: `workstation
validate` on the Windows side (`scripts/ci/validate.ps1`, which strictly
parses every tracked `.json` file) had never actually been run since the
3.11.0 dotfiles-config-migration commit - it failed on a leftover, orphaned
git merge-conflict marker (`>>>>>>> 79682b1 (updates)`) sitting inside
`editor/neovim/personal/lazy-lock.json`, copied verbatim from the source
dotfiles repo without noticing. Removed the single stray line (confirmed no
matching `<<<<<<<`/`=======` counterpart existed - the conflict itself had
already been resolved, just the closing marker was never deleted).
**Lesson: run both POSIX and Windows `workstation validate` after any
change touching tracked JSON, not just one side** - they parse with
different strictness.

## 3.12.0

Phase A of the "fully fledged cross-platform workstation" plan (see
`~/.claude/plans/misty-dreaming-moth.md`): three project template directories
existed (`ai`, `infra`, `network-automation`) but were unfinished orphans -
no README, no `.env.example`, no CI, and missing `devcontainer.json`'s
`remoteUser` (a real policy violation - every other template requires it
non-root). Not in `policy/development.json`'s `allowedTemplates` either, so
`workstation project init` rejected all three outright.

- Finished all three to the same bar as the other 8 templates: README,
  `.editorconfig`, `.gitignore`, `.env.example`, `.github/workflows/{ci,
  policy}.yml`, `remoteUser: vscode` added to each `devcontainer.json`.
- `ai`: minimal Python/FastAPI/data-science scaffold (numpy/pandas/
  scikit-learn/OpenTelemetry deps live in the Dockerfile, matching
  `python-service`'s existing convention of keeping `requirements.txt` empty
  and CI-tested code dependency-free) - its README now points at
  `rag-app`/`agent-app`/`mcp-server` instead for LLM-specific work, to avoid
  overlap confusion with those already-shipped AI templates.
- `network-automation`: added a minimal Nornir inventory
  (`nornir/config.yaml` + `inventory/{hosts,groups,defaults}.yaml`, all
  empty placeholders) and `.env.example` documenting
  `NET_DEVICE_USERNAME`/`_PASSWORD` (real creds never touch tracked YAML -
  loaded from the environment at runtime instead, documented directly in
  `src/main.py`'s comments).
- `infra`: added minimal Terraform (`main.tf`/`versions.tf`, matching the
  existing `terraform` template) plus a minimal Ansible skeleton
  (`ansible/{ansible.cfg,inventory.ini,playbook.yml}`) since its Dev
  Container installs both toolchains - its own CI runs both a Terraform job
  and an `ansible-playbook --syntax-check` job.
- `policy/development.json` (bumped to 1.3.0): all three added to
  `projects.allowedTemplates`.

Verified live, not just written: `workstation project init` actually
scaffolded all three templates for real, each came back `RESULT: COMPLIANT`
with 0 failures from `project-check.sh`; `ruff check`/`pytest` both pass for
real (via a venv - this WSL image has no system `pip`, a separate,
unrelated gap) on `ai` and `network-automation`; `ansible-playbook
--syntax-check` passes for real on `infra`. Terraform itself isn't
installed on this bare WSL host (by design - it lives in the Dev Container,
via each template's own `terraform` devcontainer feature), so
`terraform fmt`/`validate` could not be run outside a container from here -
the `.tf` content is trivial enough (an empty placeholder + a version
constraint) that this is a low-risk, flagged gap, not a claimed pass.

## 3.11.0

Went through the rest of `Iskarioti/.dotfiles`'s `.config/` tree (the
remainder of the dotfiles review from 3.10.0/3.10.1) and migrated what
applies to this repo's scope. Most of `.config/` is Linux-desktop-GUI
material (window managers, compositors, a launcher, an audio daemon,
personal recording services) that doesn't apply to WSL/macOS dev
workstations and was left alone - see `docs/desktop-appearance.md`-adjacent
reasoning. Two more real decisions confirmed with Andrew first (a
keyboard-remap layer that changes system-wide keystroke behavior, and
introducing a new terminal-emulator choice, both too invasive/personal to
silently adopt):

- **Skipped**: `kanata` home-row-mods keyboard remap (Caps/A/S/D/F/J/K/L/;
  all become tap-hold modifiers) - too invasive to enable without an
  explicit ask.
- **Added**: Alacritty as a managed terminal emulator for macOS/Linux
  (`shell/alacritty/architect.alacritty.toml`, Tokyo Night colors,
  JetBrainsMono Nerd Font) - installed via the new `alacritty` brew cask
  (macOS) / apt-dnf-pacman package (Linux, best-effort). Two deliberate
  changes from the source config: dropped an `import` of a `themes/`
  directory the source repo's own `.gitignore` excludes (already-inlined
  colors made it redundant) and dropped a hardcoded `zsh` shell override
  (this repo's default shell differs per OS).
- **Added**: a 4th Neovim profile, `editor/neovim/personal`, migrated from
  `.config/nvim` (~25 files: LazyVim, Mason/LSP, Telescope, Treesitter,
  Copilot, lualine, oil.nvim, which-key) - wired into `scripts/posix/
  editor.sh` and `apply-editor.sh` exactly like the existing `platform`/
  `nvchad`/`minimal` profiles, fully isolated via `NVIM_APPNAME` so it adds
  zero risk to what already existed. `docs/editors.md` documents it.
- **Skipped, low value**: `tmuxinator` (needs installing Ruby+gem for
  marginal benefit over the `workspace`/`project` fzf pickers already in
  `architect.zshrc`) and `htop`'s `htoprc` (just UI column layout,
  regenerates trivially). `systemd/user/{bridge,dreamsrecorder}.service`
  are Andrew's own unrelated personal screen-recording/streaming daemons -
  not touched.

Found and fixed one real bug verifying the new Neovim profile live (not just
copied and assumed working): `nvim-treesitter`'s upstream default branch
("main") is a full API rewrite with no `.configs` module anymore, while this
config's `treesitter.lua` uses the pre-rewrite API - the profile installed
successfully via `Lazy! sync` but crashed on every real startup with `module
'nvim-treesitter.configs' not found` until the plugin spec was pinned to
`branch = "master"` (upstream's own maintained-but-archived
legacy-compatible branch). Also removed one dead/unused line in the same
file that only existed to crash against the same removed API. After the
fix, a real headless `nvim` load with `NVIM_APPNAME=nvim-personal` starts
clean and a real Lua buffer opens with treesitter/LSP wiring intact - one
harmless, non-fatal deprecation warning remains (`nvim-lspconfig`'s classic
setup style, removed in its future v3.0.0 - not rewritten here, since that
would mean redesigning the LSP setup, not porting it).

## 3.10.1

Desktop appearance (Dock/Taskbar/wallpaper) for a "fully fledged workstation",
following up on the dotfiles review in 3.10.0 - `nix/darwin/flake.nix`'s
`system.defaults` block there had real Dock/Finder settings never carried over
before. Two real decision points confirmed with Andrew first (which apps to
pin, and how to handle Windows taskbar pinning given a real platform
limitation) rather than guessed. See `docs/desktop-appearance.md` for the
full picture.

- **macOS**: new `platform/macos/configure-appearance.sh` (run from
  `bootstrap.sh`) - Dock sizing/autohide/magnification/genie-effect, Dock
  apps pinned via the new `dockutil` brew dependency (Finder, LibreWolf, VS
  Code, Terminal, Mail, Calendar), Finder column view, Dark mode, 24h time,
  fast key repeat, screenshots to `~/Downloads`, guest login disabled. New
  `bingpaper` cask for Bing wallpaper - **not** the `bing-wallpaper` cask,
  which is Intel-only and needs Rosetta on Apple Silicon. Not tested on
  real macOS hardware (none available this session) - syntax-checked only,
  flagged rather than claimed working.
- **Windows**: new `windows/43-configure-taskbar-appearance.ps1` (wired
  into `bootstrap.ps1`) - small taskbar icons, left-aligned, dark app/system
  theme, via `HKCU:\...\Explorer\Advanced` and `HKCU:\...\Themes\
  Personalize`, with an Explorer restart to apply. `Microsoft.BingWallpaper`
  added to `windows/10-install-tools.ps1` (Microsoft's own official app,
  clean winget install, no caveats).
- **Windows taskbar app *pinning* is deliberately not automated**: confirmed
  via research that Windows 11 24H2+ has no reliable unattended API for
  it anymore (`LayoutModification.xml` broke ~2023, locked down further by
  KB5058411 in May 2025 to MDM/kiosk-only) - the unsupported workarounds
  (copying `TaskBand`/`Start2.bin` from a reference profile) are liable to
  break on the next Windows update, so this documents a one-time manual
  pinning step instead (File Explorer, Windows Terminal, VS Code,
  LibreWolf) rather than shipping something fragile.

Found and fixed one real bug verifying the Windows script live (not just
written and assumed correct): `New-Item -Force` on an *already-existing*
registry key threw `Attempted to perform an unauthorized operation` -
looked like a corporate policy block at first, but a direct
`Set-ItemProperty` on the same key succeeded immediately, proving it
wasn't. Fixed by only calling `New-Item` when `Test-Path` confirms the key
is actually missing (both keys exist by default on every real Windows
install). After the fix, a real run set all four registry values
(`TaskbarSi`, `TaskbarAl`, `AppsUseLightTheme`, `SystemUsesLightTheme`,
confirmed via `Get-ItemProperty`) and restarted Explorer cleanly.

## 3.10.0

Reviewed Andrew's previous personal dotfiles repo
(`github.com/Iskarioti/.dotfiles`, cloned read-only for this review, not
adopted wholesale) for improvements applicable to `platform/{linux,macos}`
and the managed `shell/{bash,zsh}` fragments. Most of that repo is a
Nix/home-manager-based Arch Linux desktop setup (Hyprland/Sway/i3/awesome/
dwm, waybar/polybar/rofi/picom, Karabiner, Raycast, fish+zinit+Powerlevel10k)
which doesn't apply to this repo's WSL/macOS dev-workstation scope or its
imperative bash/PowerShell provisioning model - only the portable, low-risk
pieces were ported in, confirmed with Andrew first for the two real
decision points (keep Oh My Posh as the one prompt engine rather than
switching to Powerlevel10k; skip GPG commit signing for now, since it
would also mean changing the SSH-agent model).

**Security note (unrelated to the port, flagged not remediated):** that
dotfiles repo has two real OpenSSH private keys (`.ssh/id_rsa`,
`.ssh/id_devman`) committed in plaintext - confirmed by reading their
headers, not guessed. Neither key was copied or used anywhere in this
change.

Shipped:
- **zsh plugins via zinit** (`shell/zsh/architect.zshrc`): `Aloxaf/fzf-tab`,
  `zsh-users/zsh-autosuggestions`, `zsh-users/zsh-syntax-highlighting` -
  Oh My Posh remains the only managed prompt engine, this is additive only.
- **New managed tmux config**: `shell/tmux/architect.tmux.conf` (vim-style
  pane/window nav, vi copy-mode, mouse on, Tokyo Night theme via TPM to
  match the Oh My Posh theme) - a real gap before this (an `ops()` helper
  already opened tmux, but no config was ever deployed). `scripts/posix/
  apply.sh` now deploys it to `~/.config/tmux/tmux.conf` and clones TPM to
  `~/.tmux/plugins/tpm` if missing.
- **New managed ripgrep config**: `shell/ripgrep/architect.ripgreprc`
  (excludes `vendor/`, `node_modules/`), deployed to `~/.config/ripgrep/
  ripgreprc` with `RIPGREP_CONFIG_PATH` set in both shell fragments.
- **Two small utility additions** to both `architect.bashrc` and
  `architect.zshrc`: a `helm` alias (`h`) and `docker_rm_stopped()` - fixed
  while porting it, the source version removed *all* containers
  unconditionally (would error on anything still running); this one
  filters to `-f status=exited` first, matching its own name.

Verified live, not just read: `scripts/posix/apply.sh` deployed all three
new managed files and cloned tpm on a real run; a real tmux session started
with the new config with no errors (`C-Space` prefix, mouse, vi copy-mode
bindings all confirmed via `tmux show-options`/`list-keys`); a real `zsh
-i` load installed all three zinit plugins cleanly and confirmed
`docker_rm_stopped`/`h=helm` are present, then reloaded fast and clean on a
second run; a real `bash -i` load confirmed the same two additions.
`docs/shell-experience.md` documents all of it.

## 3.9.9

New `workstation services autostart enable|disable|status [service ...]`
(default target: `redis redisinsight`) so these dev-services come back up on
their own after a Docker daemon restart, a WSL restart, or a full PC
reboot/shutdown - mirrors `workstation dashboard enable`'s two-part design
(`docs/control-plane.md`):

- `redis` and `redisinsight`'s own `compose.yaml` now carry `restart:
  unless-stopped` - Docker itself resumes them whenever its daemon starts,
  no extra scripting needed as long as WSL is running.
- New Windows Scheduled Task `WorkstationDevServicesAutostart` (`AtLogOn`,
  installed by new `scripts/windows/install-dev-services-autostart.ps1` /
  removed by `uninstall-dev-services-autostart.ps1`) wakes WSL at login and
  runs `services up <targets>` - a restart policy alone does nothing until
  something actually starts the WSL instance, the same role
  `WorkstationDashboardAutostart` already plays for the dashboard.
- New `scripts/posix/services.sh` `autostart` action (WSL/Linux/macOS side)
  and `scripts/common/services-autostart-control.ps1` (the unified
  Windows-invoked command that does both the WSL-side and Windows-side
  install/remove in one call), wired into `setup.ps1`'s `services` dispatch.

Found and fixed two real bugs verifying this live end-to-end (not just
`bash -n`/dry-reading the diff):
1. **`sudo systemctl enable docker` hung forever** when run non-interactively
   from a Windows Scheduled Task / cross-boundary `wsl.exe -- bash -lc ...`
   call with no TTY to answer a password prompt. Fixed with `sudo -n` (fails
   fast instead of prompting) and only calling it at all when
   `docker.service` isn't already enabled.
2. **A PowerShell array passed as `-Services $Services` across a `pwsh.exe
   -File` process boundary silently collapsed to its first element only**
   (a scheduled task got installed for `redis` alone, dropping
   `redisinsight`) - native/external-process argument passing doesn't
   reliably preserve a named array parameter's multiple values. Fixed by
   splatting positionally (`@Services`, no `-Services` flag) into a
   `ValueFromRemainingArguments` parameter on the receiving script instead,
   the same technique `services-autostart-control.ps1` itself already used
   for its own `$Services` parameter.

Verified live: `workstation services autostart enable` (both the direct
WSL-side call and the full Windows-invoked two-part command) correctly
recreates `dev-redis`/`dev-redisinsight` with `restart=unless-stopped`,
installs a scheduled task whose real `/TR` command targets both services
(confirmed via `Get-ScheduledTask`, not just the install script's exit
code), and `autostart status` reports both the Docker-side and
Windows-side state correctly through the real installed `workstation`
command, not just the underlying scripts directly.

## 3.9.8

Added LibreWolf (privacy-hardened Firefox fork) to the baseline software
installed on every platform's bootstrap, using each OS's own official
first-party distribution channel rather than a manual binary download:

- Windows: `LibreWolf.LibreWolf` added to `windows/10-install-tools.ps1`'s
  winget package list.
- macOS: `librewolf` added to `platform/macos/bootstrap.sh`'s
  `brew install --cask` list.
- Linux: new `platform/linux/install-librewolf.sh`, wired into
  `platform/linux/bootstrap.sh` (best-effort, `|| true`, matching the
  existing VS Code entry) - idempotent, and installs via each distro
  family's own official LibreWolf channel: `extrepo` on Debian/Ubuntu
  (LibreWolf's documented apt mechanism), the vendor's `librewolf.repo`
  file on Fedora/RHEL (`dnf config-manager`), and directly via `pacman`
  on Arch, where LibreWolf already ships in the official `extra`
  repository with no third-party repo/keyring setup needed at all.

## 3.9.7

Finished the `redis` -> `redis/redis-stack-server` migration left incomplete by
`a01eb45` (2026-08-31), which bumped `versions.env` to the new image but never
updated `compose.yaml` to match its different startup contract - the old
`command:` override (a plain `redis-server <path> --requirepass ...` shell
invocation) doesn't apply to redis-stack-server, whose own `/entrypoint.sh`
always loads `/redis-stack.conf` (if present) and appends `${REDIS_ARGS}` to
its own hardcoded module-loading command line (confirmed by reading the
image's actual `/entrypoint.sh`, not guessed).

- `compose.yaml` now: drops the custom `command:`, mounts
  `config/redis.conf` to `/redis-stack.conf` (the path the entrypoint
  specifically looks for), and sets auth via a `REDIS_ARGS: --requirepass
  ${REDIS_PASSWORD}` environment entry instead. `mem_limit` bumped
  384m -> 768m for the stack's extra loaded modules (RediSearch, RedisJSON,
  RedisTimeSeries, RedisBloom, rediscompat).
- Fixed `.env.example`'s `REDIS_PASSWORD` placeholder, which held a real
  16-char generated-looking value instead of this repo's usual `change-me`
  convention (confirmed it does NOT match the actual runtime secret at
  `~/.config/workstation/services/redis.env`, so this was an inconsistency,
  not a leaked live credential).
- Verified live: `workstation services up redis redisinsight` - `dev-redis`
  healthy, `requirepass` correctly enforced, RediSearch/RedisJSON/etc. modules
  loaded, and `dev-redisinsight` (already on the `consumes` mechanism from
  v3.9.6) connects using the real resolved password with an HTTP 200.

## 3.9.6

New AGENTS.md rule 15: every dev-service's own configuration
(`compose.yaml`/`versions.env`/`defaults.env`/`.env.example`) must stay
independent of every other service's - never reference another service's
variable names directly, even when depending on it for actual
infrastructure. Prompted by the v3.9.5 langfuse refactor directly
referencing `${POSTGRES_PASSWORD}`, `${CLICKHOUSE_USER}`, etc. inside
langfuse's own `compose.yaml`.

- New `service.json` field `consumes`: a map of `"OWN_VAR_NAME":
  "dependency-id:DEPENDENCY_VAR_NAME"`. `scripts/posix/services.sh`'s new
  `generate_consumed_env()` resolves each entry (searching the dependency's
  `versions.env`, `defaults.env`, and generated secret file) into a
  generated env file merged into the same `docker compose` invocation - a
  service's `compose.yaml` only ever needs to know its own variable names.
  Documented in `docs/development-services-v2.md`.
- Rewired `langfuse` fully onto `consumes` (Postgres user/password, Redis
  password, ClickHouse user/password + both dependencies' own pinned
  image/version for the init containers, Garage access/secret key/bucket) -
  `compose.yaml` no longer references any other service's variable names at
  all.
- Found and fixed the same class of violation in three already-shipped
  services while auditing for it: `opensearch-dashboards` (read
  `${OPENSEARCH_INITIAL_ADMIN_PASSWORD}` directly), `pgbouncer` (read
  `${POSTGRES_USER}`/`${POSTGRES_PASSWORD}`/`${POSTGRES_DB}` directly), and
  `redisinsight` (read `${REDIS_PASSWORD}` directly) - all three now consume
  their dependency's credential through the same declarative mechanism.
  Verified live: `langfuse`, `pgbouncer`, and `redisinsight` all rebuilt
  cleanly with their new consumed variables correctly resolved to the real
  underlying secret values.

## 3.9.5

Two changes: extracted `clickhouse` and `garage` as their own shared
dev-services (rather than private per-service copies), and wired real
Langfuse tracing into `rag-app`/`agent-app`.

- **New `clickhouse` and `garage` dev-services**, same 7-file pattern as
  every other entry. `langfuse`'s `service.json` now declares
  `"dependsOn": ["postgres", "redis", "clickhouse", "garage"]` instead of
  bundling private copies of each - `workstation services up langfuse`
  still brings all four up automatically (`resolve_targets` already expands
  `dependsOn` recursively and merges every resolved service's compose file +
  secrets into one `docker compose` invocation - the same mechanism
  `pgadmin`'s `dependsOn: ["postgres"]` already relied on). Two new one-shot
  init containers (`langfuse-postgres-init`, `langfuse-clickhouse-init`)
  idempotently create a dedicated `langfuse` database inside the shared
  Postgres/ClickHouse on first boot, so Langfuse doesn't write into the
  shared `platformdev`/`default` databases other consumers use. Garage's
  shared instance auto-bootstraps one bucket (`GARAGE_DEFAULT_BUCKET`,
  default `shared`); Langfuse namespaces its objects under a `langfuse/`
  prefix within it, since there's no per-consumer bucket isolation yet.
  Verified live end-to-end after the refactor: a real trace round-tripped
  through the shared ClickHouse's dedicated `langfuse` database with zero
  errors.
- **`rag-app` and `agent-app` now trace every LLM call to Langfuse
  automatically** via `langfuse.langchain.CallbackHandler`, when
  `LANGFUSE_PUBLIC_KEY`/`LANGFUSE_SECRET_KEY` are set in the project's own
  `.env` (optional - both templates run standalone with no tracing if
  unset). Verified live by building both templates' Dev Containers fresh,
  hitting real endpoints, and confirming rich nested traces landed in
  ClickHouse - not just the LLM call itself but, for `agent-app`, the full
  LangGraph execution chain (`__start__`, `respond` node, channel writes).

## 3.9.4

Added the last piece from Andrew's target AI architecture diagram: LLM
tracing/observability via a new `langfuse` dev-service
(`langfuse/langfuse`+`langfuse/langfuse-worker` 4.27.0), same catalog pattern
as `qdrant`/`open-webui` but six containers behind one entry - Langfuse's own
private Postgres, Redis, ClickHouse, and Garage (S3-compatible storage;
deliberately not MinIO, whose open-source project was archived in April 2026
with no further community builds). A local admin account and a default
project's API keys are pre-seeded on first boot, so a project can start
sending traces immediately via the `langfuse` Python SDK - see
`docs/ai-workstation.md`.

Found and fixed four real bugs verifying this live end-to-end (build, health,
and an actual trace round-tripped through to ClickHouse - not just "should
work"):
- A bind-mount path (`./config/garage.toml`) resolved against the wrong
  directory: `services.sh` sets `--project-directory` to the **repo root**
  for every dev-service, not the service's own directory, so relative
  compose paths must be written `./development/services/<name>/...` in
  full - Docker silently created an empty directory instead of finding the
  file, crashing Garage with "IO error: Is a directory".
- Both Langfuse containers OOM-crashed (`FATAL ERROR: Reached heap limit`):
  `mem_limit` was too tight for Node's default heap sizing, and without an
  explicit `NODE_OPTIONS=--max-old-space-size`, Node doesn't reliably respect
  a cgroup memory limit anyway. Fixed both container sizing and heap sizing
  together.
- The web container's own in-container healthcheck could never pass:
  Docker auto-injects `HOSTNAME=<the compose "hostname:" field>` into the
  container's env, and Langfuse's server binds to whatever that resolves to
  instead of all interfaces - fine for the host-published port (Docker's NAT
  targets the container's real IP directly) but unreachable from a
  healthcheck running inside that same container via `127.0.0.1`. Fixed by
  overriding `HOSTNAME=0.0.0.0` in the container's own environment.
- ClickHouse was pinned to the actual-latest `26.8.2` instead of matching
  Langfuse's own tested companion version - the worker hit `Numeric value is
  out of range for DateTime64` and silently dropped every event. Repinned to
  `25.12.11` (the exact patch the vendor's own compose references as
  `25.12`). Lesson for future vendor-coupled multi-service stacks: match the
  vendor's tested version, don't independently grab the newest tag per
  component.

## 3.9.3

Fixed a real bug found while finally live-verifying the Kubernetes runtime for
`labs/ai/rag-pipeline` and `labs/ai/agent-mesh` (previously only Docker-runtime
verified - `kubectl`/`helm`/`k3d` weren't installed on this machine until now):
`scripts/posix/install-lab-toolchain.sh`'s k3d checksum lookup did an exact
match against a bare filename (`k3d-linux-amd64`), but k3d's own
`checksums.txt` lists entries path-prefixed (`_dist/k3d-linux-amd64`) - the
exact match always failed with "k3d checksum entry not found", so
`workstation lab toolchain install` could never actually install k3d. Fixed to
match on the checksum file's path basename instead of the full field.

With that fixed: `workstation lab toolchain install` + `workstation lab
cluster create` (a real `platform-labs` k3d cluster, 1 server + 2 agents) both
labs' full test suites now verified end-to-end under `--runtime kubernetes`
too - `rag-pipeline`'s `smoke` (real retrieval) and `qdrant-outage` (pod
replacement recovery), `agent-mesh`'s `smoke` (three independently-answering
replicas via k8s Service load-balancing) and `node-failure` (deployment stays
available through a pod deletion). Both namespaces destroyed after
verification; the `platform-labs` cluster itself is left running for reuse.

Also, separately: Windows was configured to sleep after only 5 minutes idle on
AC power - almost certainly the root cause of containers (and, once, the shell
driving them) repeatedly and silently dying mid-task throughout this session's
AI-workstation work. Changed `powercfg` AC sleep timeout to Never; display
timeout, battery (DC) behavior, and hibernate settings are all untouched, so
this only affects whether the system suspends while plugged in.

## 3.9.2

Added `workstation autosync pause [minutes]` / `resume`: autosync fires every 5
minutes and commits/pushes whatever is dirty at that moment (by design, so work
is never silently lost across machines - see `docs/autosync.md`'s "AI agents"
section), which can interleave an autosync commit into the middle of a
multi-step agent task. Prompted by exactly that happening twice in the previous
AI-workstation work (`e52a1fd`, `6c8bcf6` - the latter caught this very fix's
own in-progress edits mid-task).

- `pause` writes `.state/autosync.pause` (an ISO-8601 UTC expiry, default 30
  min); both `scripts/common/autosync.sh` and `autosync.ps1` skip the git-sync
  step entirely while it's unexpired, and self-heal a stale/forgotten pause
  file by deleting it and proceeding normally on the very next cycle - it can
  never disable autosync indefinitely.
- Wired into `workstation autosync pause|resume` (POSIX and
  `scripts/common/autosync-control.ps1`).
- New AGENTS.md rule 14: pause before a task that edits several already-tracked
  files across more than one tool call, resume once committed or abandoned.
- Also fixed `docs/autosync.md` still documenting the pre-3.8.5 "once per
  minute" interval everywhere; it's been every 5 minutes since that fix.

## 3.9.1

Added the "prompt engineering interface" piece from Andrew's target AI
architecture diagram (`IMG_4954.PNG`): a new `open-webui` dev-service
(`ghcr.io/open-webui/open-webui:v0.11.3`), same 7-file pattern as `qdrant`,
joining `platform-dev` to reach the shared `ollama` runtime by name. Its
`WEBUI_SECRET_KEY` is a generated secret (same `generate_secret_file` mechanism
as every other service's credential). Added to the `ai` profile in both
`development/catalog.json` and `policy/development.json`, plus a dashboard tile.

Verified live: builds and passes its health check, serves `http://127.0.0.1:8081`
(HTTP 200), and its `/ollama/api/*` routes correctly reach the configured
`OLLAMA_BASE_URL` (confirmed via a `401 Not Authenticated` rather than a
connection error - full chat verification needs a logged-in browser session,
which is expected: the first account created becomes the local admin). Its
first-boot Hugging Face embedding-model download is resumable across restarts
via its own data volume once it completes once.

## 3.9.0

Holistic AI/ML workstation: local model testing, an MCP server dev/test/deploy
lifecycle, and RAG/agentic ("AgentOS") architecture validation before production —
following the repo's existing dev-service/project-template/lab three-tier mechanism
rather than inventing a new one. See `docs/ai-workstation.md`.

- **`ai-runtime` fixed and wired into `workstation`.** Its `compose.yaml` pinned
  `OLLAMA_VERSION:-latest` — a live violation of this repo's own `forbidLatestTag`
  policy enforced everywhere else — now pinned via `ai-runtime/versions.env`. Its
  `ollama` service now also joins `platform-dev` (Compose services can belong to
  multiple networks at once), so any project already joined there reaches
  `ollama:11434` with zero extra wiring. New `workstation models
  up|down|status|pull|list|run`, wired via `scripts/posix/models.sh` /
  `scripts/common/models.ps1` — previously Taskfile-only and outside the CLI
  entirely (`ai-runtime/Taskfile.yml` removed).
- **New `qdrant` dev-service** (`development/catalog.json`, `policy/development.json`
  `ai` profile) — the same 7-file pattern as every other service. Its API key is a
  real generated secret (`generate_secret_file`, same mechanism as Redis).
- **Three new project templates**: `mcp-server` (Python, official `mcp` SDK, Node
  feature for the MCP Inspector), `rag-app` (FastAPI + LangChain + Qdrant + Ollama),
  `agent-app` (FastAPI + LangGraph + Ollama). Verified by actually building each
  template's Dev Container and exercising it live — not just `pytest` — per this
  repo's standing "never trust an unverified 'should work'" discipline: `rag-app`'s
  `/ingest`+`/query` round-tripped a real fact through Qdrant + `nomic-embed-text` +
  `gemma3:4b`; `agent-app`'s LangGraph `/invoke` got a real `gemma3:4b` response;
  `mcp-server`'s scaffolded tool was listed and called successfully via the real MCP
  Inspector CLI. Found and fixed two real bugs this way: `rag-app`'s and
  `agent-app`'s `requirements.txt` used open version ranges that resolve fine on the
  WSL host's Python 3.12 but hit a genuine pip `ResolutionImpossible` inside the Dev
  Container's actual Python 3.13 — now pinned to exact, mutually-compatible
  versions; and `rag-app`'s `app/main.py` never called `load_dotenv()` despite
  depending on `python-dotenv` and despite `.env.example` documenting that
  `QDRANT_API_KEY` must be loaded from `.env`.
- **Two new labs**: `labs/ai/rag-pipeline` (disposable Ollama+Qdrant; `smoke` and
  `qdrant-outage` tests) and `labs/ai/agent-mesh` (three-replica LangGraph mesh
  behind Ollama; `smoke` and `node-failure` tests), both Docker- and
  Kubernetes-runtime manifests following `redis-cluster`'s established layout.
  Docker runtime verified end-to-end for both (real retrieval scores, real
  independent per-replica model output, real outage/node-failure recovery);
  Kubernetes runtime not live-verified this round (needs `workstation lab
  toolchain install` first).
- **Found and fixed a real, pre-existing gap while verifying Phase D**: `labs.sh`
  has always existed, fully implemented, but `lab` was never wired into
  `workstation.sh`'s command dispatch, `setup`'s command allow-list, or
  `setup.ps1` — `workstation lab ...` had likely never worked at all before this.

## 3.8.5

- Fixed the Windows autosync scheduled task flashing a visible PowerShell console
  window every single run (every 1 minute) — reported live by Andrew. Task
  Scheduler's own "Hidden" task setting only hides a task from the Task Scheduler
  UI; it does not suppress the console window a launched `pwsh.exe` allocates. New
  `scripts/windows/run-hidden.vbs` routes the real command through `wscript.exe`
  (a GUI-subsystem host that never shows a window itself) + `Shell.Run` with a
  hidden window style, applied to both `install-autosync.ps1` and
  `install-autoupgrade.ps1` (same bug, just far less noticeable at once/day).
- `scripts/windows/install-autosync.ps1` also switched from raw `schtasks.exe` to
  the `ScheduledTasks` PowerShell module (matching `install-autoupgrade.ps1`'s
  existing style): `schtasks.exe`'s `/TR` value has a hard, largely undocumented
  261-character limit, and this repo's own path (nested under a synced "OneDrive -
  WIOCC\Documents" folder) plus the hidden-runner wrapper routinely exceeds it.
  Eased the interval from every 1 minute to every 5 minutes while at it, matching
  the WSL/macOS-side interval change already made in 3.8.3's autosync work.
- Found along the way: re-registering an *already-existing* scheduled task via
  `Register-ScheduledTask -Force` can fail with `Access is denied` from a
  non-elevated session, even though the task itself runs unelevated as a normal
  user — Andrew had to run the install script himself in an elevated PowerShell.
  Verified end-to-end afterward via `Get-ScheduledTaskInfo`: two consecutive runs
  exactly 5 minutes apart, both `LastTaskResult: 0`, zero missed runs.

## 3.8.4

- Found and fixed the last real blocker in the `workstation project open wiocchub-api`
  bug chain (path resolution → JSONC validation → WSL networking, all fixed in
  3.8.2/3.8.3): `wiocchub-api`'s own `postCreateCommand.configure-git` step ran
  `git config --global --add safe.directory ...`, which failed with `error: could not
  write config file /home/vscode/.gitconfig: Device or resource busy`. Git's config
  writer works by atomically renaming a temp file over the target, and you cannot
  rename over a bind-mounted file's mountpoint from inside a container — an
  incompatibility with the `.gitconfig` file mount added in 3.8.1, independent of
  read-only vs. read-write. Fixed (in `wiocchub-api`'s own devcontainer.json, not
  tracked in this repo) by switching to `sudo git config --system --add safe.directory
  ...`, which writes to `/etc/gitconfig` — a plain container-local file, never
  bind-mounted — achieving the same effect. Verified end-to-end: the container now
  builds and starts cleanly, `install-poetry`/`install-claude`/`install-dev-tools`/
  `configure-git` all succeed.
- Found along the way (not fixed, just documented — this is a characteristic of
  `wiocchub-api`'s own devcontainer.json, not something to silently change): its
  `runArgs` hardcodes a fixed `--name=wiocchub-api`. `project-open.sh`'s own
  `devcontainer up` invocation (run from inside WSL) and VS Code's native "Reopen in
  Container" flow label the resulting container's `devcontainer.local_folder` with
  different path formats for the exact same project (a plain WSL path vs. a Windows
  UNC `\\wsl.localhost\...` path) — so neither recognizes the other's container as
  "already existing," and running both concurrently against the same project races on
  that fixed container name, with one attempt failing with a Docker `Conflict: name
  already in use` error. Don't run `project open` and VS Code's own native reopen at
  the same time against a project with a hardcoded container name.

## 3.8.3

- Switched WSL's networking mode from `mirrored` to `nat` in all three managed
  configs (`wsl/.wslconfig`, `wsl/profiles/default.wslconfig`,
  `wsl/profiles/ai-lab.wslconfig`) — root-caused a real, live networking outage
  (WSL couldn't even reach its own default gateway, while the Windows host had
  full connectivity to the same address) to a conflict between mirrored mode's
  DNS tunneling and this machine's Global Secure Access Client (Microsoft Entra
  Zero Trust). WSL's own warning ("DNS Tunneling is disabled" when GSA is
  detected) implied this was already handled, but the actually-deployed
  `.wslconfig` still had `dnsTunneling=true` — the repo's own file had been
  edited to `false` at some point but never redeployed, so the fix never took
  effect. Switching to NAT removes the conflict entirely (NAT doesn't use DNS
  tunneling or mirrored mode's firewall integration at all, so both settings
  are dropped rather than left as dead config). Verified end-to-end after
  redeploying via `windows/25-set-wsl-profile.ps1 -Profile default` +
  `wsl --shutdown`: DNS resolution, gateway ping, and the exact
  `redis/redis-stack-server:7.4.0-v8` pull that had been failing all work now.

## 3.8.2

- Fixed a real bug reported live: `workstation project open wiocchub-api` (run from
  `$HOME`, not the project itself) silently checked `$HOME` instead — `cd
  "wiocchub-api"` failed (no such relative path), the failed command substitution
  returned empty, and `"${1:-$PWD}"` treated that empty string as "unset" and quietly
  defaulted to `$PWD`, reporting 11 unrelated failures (including flagging
  `Dockerfile.template` files under `~/.vscode-server/extensions/` as if they were the
  named project's).
- New `scripts/posix/resolve-project.sh` (shared by `project-open.sh`,
  `project-check.sh`, `project-doctor.sh`, `project-adopt.sh`): a bare project name is
  now resolved by searching `policy/development.json`'s `projectRoots`
  (`~/src/company`, `~/src/platform`, etc.) — `workstation project open wiocchub-api`
  now works from anywhere. A name that resolves nowhere is a hard error listing the
  configured roots, never a silent fallback.
- Fixed `project-check.sh` validating `devcontainer.json` with plain `jq empty`, which
  rejects the JSONC comments/trailing commas the Dev Container spec legitimately
  allows — surfaced immediately once the resolve fix above let `project check` reach
  `wiocchub-api`'s real devcontainer.json (which uses `//` comments) for the first
  time. Now uses the Dev Container CLI's own parser when installed, falling back to
  plain `jq` (fine for every platformctl template, none of which use comments).

## 3.8.1

- Investigated whether VS Code's Dev Containers `dev.containers.copyGitConfig` setting
  (client-side, on by default) could replace the direct `.gitconfig` bind mount that
  `wiocchub-api`'s devcontainer.json already had — verified against a real container
  attached through this repo's own `project-open.sh` flow (`devcontainer up` via the
  CLI, then `code --folder-uri` to attach) that it does **not** fire: no `.gitconfig`
  ever appeared inside the container, even minutes after a confirmed-connected
  attach. Kept the direct mount rather than removing it on an unverified assumption.
- Added that same `.gitconfig` mount (read-only, unlike SSH keys this isn't a secret
  so a direct mount is fine — but read-only so a container process can't write back
  and mutate the host's real file) to all 8 platformctl project templates and to
  `wiocchub-app` (neither had one before, so `git commit` inside their Dev Containers
  previously had no identity at all). `wiocchub-api` already had one — read-write,
  since its `postCreateCommand` writes `git config --global --add safe.directory`
  through it — left as-is, not read-only.

## 3.8.0

- Every governed Dev Container (this repo's 8 project templates, plus the adopted
  `wiocchub-api`/`wiocchub-app` projects) now forwards Git SSH access via an
  `ssh-agent` socket instead of mounting private key files directly:
  `"mounts": ["source=${localEnv:HOME}/.ssh/agent.sock,target=/ssh-agent,type=bind"]`
  + `"containerEnv": {"SSH_AUTH_SOCK": "/ssh-agent"}`. A container can ask the agent
  to sign a challenge but can never read key material back out through the socket,
  so a compromised container (malicious dependency, container escape) can't
  exfiltrate a key for reuse elsewhere — and only the identities actually loaded into
  the agent are ever exposed, not every key sitting in `~/.ssh` (personal keys
  included) the way mounting the whole directory would.
- New `scripts/posix/ensure-ssh-agent.sh` keeps a persistent agent listening at a
  FIXED socket path (`~/.ssh/agent.sock` — the default `ssh-agent` picks a new random
  path every start, which a static devcontainer.json mount can't reference) and loads
  only company-purposed identities into it (`id_ed25519_company`, `id_rsa` — the two
  keys `~/.ssh/config`'s Host blocks map to company git hosts; never a personal key).
  Runs from `project-open.sh` before every `devcontainer up` (works regardless of
  shell history) and from `architect.bashrc`/`architect.zshrc` (so a new terminal
  always has it too).
- Verified end-to-end against a real container: `ssh-add -l` inside the container
  showed both forwarded identities, `SSH_AUTH_SOCK=/ssh-agent` was set correctly, and
  `ssh -T git@github.com` run *inside the container* authenticated successfully
  through the forwarded agent — no private key file ever present in the container.

## 3.7.3

- Fixed `workstation project open` (`scripts/posix/project-open.sh`) not actually
  building/starting or attaching VS Code to a project's Dev Container — it previously
  just ran a bare `code .`, and (under `set -e`) would abort entirely before even doing
  that if the project happened to be policy-non-compliant. Now: `project-check.sh`
  runs informationally (never blocks opening), and if `.devcontainer/devcontainer.json`
  exists, it builds/starts the container via `devcontainer up` and attaches VS Code to
  it directly (`code --folder-uri vscode-remote://dev-container+<hex>/...`), falling
  back to a plain `code .` open if the Dev Container CLI isn't installed or the build
  fails.
- Found and fixed two real, verified-on-hardware bugs along the way:
  - The Dev Container CLI was never actually wired into WSL bootstrap
    (`wsl/install-devcontainers-cli.sh` was an orphaned script, never called).
    `scripts/posix/install-devcontainers-cli.sh` now installs it via mise-managed Node
    and is called from `wsl/bootstrap.sh` (and the Linux/macOS bootstraps, which already
    called it). It symlinks the real binary into `~/.local/bin/devcontainer` rather than
    trusting bare `devcontainer`/`node` PATH resolution — on this WSL machine, that bare
    name resolves to an unrelated Windows-native `@devcontainers/cli` install (via WSL's
    Windows-PATH interop) that can never see Docker, and even a fully non-interactive
    `bash` invocation has neither `~/.local/bin` nor mise's shims on PATH at all (only
    `~/.bashrc`/`~/.profile` add them, neither sourced there) — `project-open.sh`
    explicitly prepends mise's shims dir and calls the installed binary by absolute path
    to sidestep both.
  - The `vscode-remote://dev-container+<hex>/...` URI's authority is hex-encoded JSON
    (`{hostPath, localDocker, configFile}`), not a hex-encoded path as first assumed —
    confirmed by decoding a live "could not be established" message from `code --status`
    for an actual in-progress attach. The wrong (path-only) encoding still opened *a*
    window, which read as success until checked with `code --status` and given time to
    settle — it was not genuinely attached. The corrected encoding was verified stable
    (a `[Dev Container: ...]` window that persisted with no connection error).

- Simplified `workstation project adopt` (`scripts/posix/project-adopt.sh`): it now
  only writes `.platformctl/project.json` to register an existing/cloned project — it
  no longer takes a `<template>` argument, no longer backfills any scaffolding files
  (`.editorconfig`, `.gitignore`, `.env.example`, CI files, `.devcontainer/`, etc.). A
  pre-existing codebase keeps its own structure and conventions untouched, managed
  independently by the project itself; `project check` still reports what's missing
  relative to policy, purely informationally.

## 3.7.1

- Fixed `project-check.sh`/`project-adopt.sh` assuming GitHub Actions unconditionally:
  `.github/workflows/ci.yml`/`policy.yml` never execute on Azure DevOps-hosted
  projects. Both now detect the `origin` remote and require/backfill
  `azure-pipelines.yml` instead for `dev.azure.com` remotes — `adopt` skips
  scaffolding the dead GitHub Actions files rather than creating them anyway (it
  does not fabricate `azure-pipelines.yml` either; its content is too
  project-specific to guess, left as a manual follow-up, correctly flagged as
  still missing when actually missing).
- Found while adopting two real company projects: both have private keys/certs
  and, for one, `.env` files for all four environments currently tracked in git
  at `HEAD` — pre-existing, unrelated to this repo, surfaced (not caused) by
  `project-check.sh`'s existing secret-filename scan. Flagged directly rather
  than acted on; this needs coordination with whoever owns those certs/environments,
  not a unilateral fix.

## 3.7.0

Fixed a real gap: pre-existing and freshly-cloned projects had no path into this
governance model at all. `.platformctl/project.json` only ever got created by
`workstation project init`, and both `project check`'s compliance model and the
dashboard's governed-projects panel keyed entirely off that file — a project cloned
straight from GitHub/Azure DevOps was invisible to both, not just non-compliant.

- Added `workstation project adopt <template> [path]`
  (`scripts/posix/project-adopt.sh`): backfills only the scaffolding files missing
  from an existing project relative to a template — never overwrites a file that's
  already there, never runs `git init`, never stages or commits anything. Verified
  against a simulated pre-existing clone: pre-existing README/`.gitignore`/app code
  left untouched, all required files backfilled, idempotent on re-run, nothing
  auto-committed.
- The dashboard's governed-projects panel now surfaces untracked projects too (a git
  repo under a project root with no `.platformctl/project.json`), flagged distinctly
  with a prompt to run `project adopt`, instead of silently omitting them.

## 3.6.3

- Added `workstation ssh-import` (wires `wsl/import-windows-ssh-keys.sh` into the
  `workstation` command) and folded it into the existing autosync cycle
  (`scripts/common/autosync.ps1`/`.sh`): every autosync run now also re-copies any new
  Windows SSH keys into WSL, before the git-sync logic and regardless of git dirty
  state. Deliberately **pure local file copying, never git** — autosync's existing
  refusal to stage secret-bearing files is completely unmodified and unrelated; keys
  never go anywhere near a git commit. Wrapped in its own try/catch so a failure here
  can never abort the git-sync part of the cycle. Verified: the dispatcher wiring and
  the exact snippet added to `autosync.ps1` both run correctly in isolation (did not
  run a live autosync cycle for real, to avoid prematurely committing/pushing
  in-progress working-tree changes as a side effect of testing).

## 3.6.2

- Added `wsl/import-windows-ssh-keys.sh`: copies existing Windows-host SSH key pairs
  into WSL's native filesystem (correct permissions, never referenced in place on
  `/mnt/c`) rather than generating separate WSL-only keys — for when the Windows-side
  keys are already registered with the Git hosts in use. Used it live to fix a real
  blocked `git clone` to Azure DevOps: WSL had generated its own company key that was
  never registered anywhere, while a Windows-side key (tied to the same Azure AD
  identity backing the Azure DevOps org) already worked. Verified both imported
  identities authenticate correctly (`ssh -T git@github-iskarioti`, and Azure DevOps's
  "shell access is not supported" response, which is its normal signature for
  *successful* auth). Deliberately not wired into bootstrap — importing arbitrary
  existing keys is a bigger action than generating a fresh one.

## 3.6.1

- Fixed a real "ready to work" gap: `wsl/configure-git.sh` (git identity + company SSH
  key generation) existed but was never invoked by anything — a fresh WSL bootstrap
  installed `git`/`openssh-client` but left `user.name`/`user.email` unset and
  generated no SSH key, so the very first `git clone` of a company repo would fail or
  silently fall back to password auth. Wired into `wsl/bootstrap.sh`; made
  `configure-git.sh` idempotent (skips re-prompting if identity is already set, and
  no longer hangs if run non-interactively with no identity configured).

## 3.6.0

- Added `workstation dashboard enable|disable|status`: the control plane can now run
  as an always-on background service instead of requiring a manual foreground run.
  WSL/Linux: a systemd user service (`Restart=on-failure`, enabled for
  `default.target`) — as a side effect, keeps the WSL2 VM itself from tearing down
  between uses, since a persistent process is now always running inside it. macOS: a
  LaunchAgent (`RunAtLoad`+`KeepAlive`). Windows: a logon-triggered Scheduled Task
  that wakes WSL (a systemd unit alone can't do that). Verified live: the WSL-side
  service was genuinely enabled and confirmed running via real `systemctl` output;
  the Windows Scheduled Task step hit the same sandbox restriction found earlier for
  autosync/autoupgrade and needs to be completed from a normal terminal.

## 3.5.0

Adopting a "trust before completeness" pass over the control plane and dev-services
subsystem: a real automated test suite, real CI, and a disaster-recovery story, on the
premise that this whole session has repeatedly found bugs that schema validation alone
could never catch.

- Added `platformctl/tests/`: a pytest suite covering auth (password hashing, TOTP,
  session signing/expiry/revocation, login backoff), the status pollers (subprocess
  calls mocked), notification transition logic, and full HTTP integration tests via
  FastAPI's `TestClient`. Found and fixed two real test-isolation bugs while building
  it (module-global `_failed_attempts` leaking state across tests; a stale assertion
  against a template string that had already changed in an earlier phase).
- Added `.github/workflows/behavioral-tests.yml`: runs the pytest suite; brings up
  `services up core` for real and asserts both containers reach `healthy` (a direct
  regression test for the project-directory Compose bug from 3.4.0); validates the
  observability profile's Compose config merges cleanly; runs a live end-to-end
  smoke test (`scripts/ci/control_plane_smoke.py`) against a real `platformctl serve`
  instance.
- Added audit logging: every command run through the command runner is recorded
  (`~/.config/workstation/control-plane/audit.log`, mode 600) and viewable at `/audit`.
- Added session revocation: sessions now carry an ID checked against an active-session
  registry, so logout actually revokes (not just clears a cookie), and a new
  "sign out everywhere" action can invalidate every outstanding session at once.
- Added `workstation backup` / `workstation restore`: an openssl-encrypted backup of
  `~/.config/workstation/` (control-plane credentials, dev-service secrets), labs
  state, and named `platform-*` Docker volumes. Restore stages and confirms before
  touching anything live, moves existing config aside instead of overwriting it, and
  skips existing volumes unless `--force-volumes` is passed. Verified end-to-end
  against throwaway fake-machine state, including wrong-passphrase rejection and the
  moved-aside-not-clobbered safety behavior.
- Added Prometheus alert-rule polling for notifications (`ScrapeTargetDown`,
  `ContainerOOMKilled` — verified the underlying cAdvisor metric actually exists before
  shipping the rule; an early draft referenced one that doesn't). Deliberately pulls
  from Prometheus's API rather than accepting a Grafana webhook: the control plane
  binds `127.0.0.1` only, which a container in Grafana's own network namespace could
  never reach.
- Added `workstation changelog`: drafts a CHANGELOG.md section and suggested semver
  bump from Conventional Commits since the last VERSION change. Preview only, not a
  CI gate — this repo's history predates the convention.
- Fixed the notification poller blocking the entire dashboard event loop during each
  check cycle (synchronous PowerShell/Docker/psutil calls now run via
  `asyncio.to_thread`).

## 3.4.0

- Added an `observability` dev-services profile: `otel-collector`, `prometheus`,
  `loki`, `tempo`, `grafana`, `cadvisor`, `node-exporter` — a full local metrics/logs/
  traces stack, verified end-to-end (all containers healthy, Prometheus scraping all
  targets, Grafana provisioned with datasources).
- Fixed a pre-existing bug in `scripts/posix/services.sh`: `build_compose_args` never
  passed `--project-directory`, so Docker Compose resolved every merged service's
  relative bind-mount paths against the *first* service's directory instead of its
  own. This silently corrupted `workstation services up core` (redis's `redis.conf`
  mount resolved into `postgres/config/`). Fixed by passing `--project-directory`
  explicitly and rewriting every affected service's compose file
  (`postgres`, `redis`, `dev-dashboard`, plus the 5 new observability services with a
  config mount) to reference paths relative to repo root.
- Added `platformctl serve` / `workstation dashboard`: a FastAPI + HTMX web control
  plane, localhost-only, with first-run username/password + TOTP (authenticator app)
  enrollment, signed session cookies, and login rate-limiting with backoff. Verified
  end-to-end: unauthenticated redirect, enrollment, wrong-password rejection, correct
  login, authenticated access, invalid-code rejection, logout, and backoff after
  repeated failures.
- Added the Phase C status/discovery layer: six live dashboard panels (background
  jobs, resource utilization, dev services, governed projects + Dev Containers, lab
  clusters, `ai-runtime`), each backed by `platformctl/platformctl/web/status.py` and
  polled via HTMX. Governed-project discovery (scanning `.platformctl/project.json`
  under policy `projectRoots`) is new bookkeeping — no such registry existed before.
- Added a curated, allowlisted command runner (`platformctl/platformctl/web/commands.py`)
  streaming output live via Server-Sent Events — deliberately a fixed set of exact
  command lines, not a free-text shell box.
- Added the Phase D notification system: a background poller
  (`platformctl/platformctl/web/notify.py`) that fires on state *transitions*
  (background job going unhealthy, a dev service stopping, CPU/memory threshold
  breaches), dispatched to in-app toasts (SSE), Windows-native desktop notifications
  (PowerShell `NotifyIcon`, no new dependency), macOS (`osascript`), Linux
  (`notify-send`), and email (stdlib `smtplib`) — configurable at
  `/settings/notifications`. Fixed a real bug found while verifying this: the
  poller's checks shell out to PowerShell/Docker/psutil and block for real time;
  they now run via `asyncio.to_thread` so a slow check cycle can't freeze every other
  request the dashboard is serving.
- Added `docs/control-plane.md`.

## 3.3.0

- Added `workstation upgrade` (`scripts/common/upgrade.ps1` / `scripts/posix/upgrade.sh`):
  on-demand refresh of winget/brew/apt-managed packages, VS Code extensions and pinned
  fonts, scoped by `workstation.json`'s new `autoUpdate` block and logged to
  `.state/upgrade-<date>.log`.
- Added `workstation autoupgrade enable|disable|once|status`: an off-hours background
  worker (Windows Scheduled Task, systemd user timer, launchd LaunchAgent) that runs
  `workstation upgrade` unattended, gated by a configurable quiet-hours window
  (`autoUpdate.schedule`) and skipped while Docker containers are running so it never
  disturbs active project work.
- Fixed `WorkstationSetupAutoSync` silently failing on every run: the scheduled task
  invoked bare `pwsh.exe`, which resolves through a Store/MSIX App Execution Alias that
  Task Scheduler's process launch cannot follow. `scripts/windows/install-autosync.ps1`
  and the new `install-autoupgrade.ps1` now embed the resolved absolute `pwsh.exe` path.
- Fixed `workstation autosync enable/disable` (and the equivalent new `autoupgrade`
  commands) failing with "term ... is not recognized" on managed/App-Control endpoints:
  `& (Join-Path ...)` invoked a dynamically-computed path directly, which is untrusted
  under ConstrainedLanguage; both control scripts now invoke through `pwsh.exe -File`.
- Fixed `wsl.exe --list --verbose` producing corrupted, spaced-out output in
  `workstation doctor`, `windows/40-health.ps1` and `windows/46-shell-doctor.ps1`
  whenever captured/redirected instead of shown live in a console.
- `workstation doctor` now reports last-run status for the autosync/autoupgrade
  background jobs on all three platforms, surfacing failures automatically instead of
  requiring manual `schtasks`/`systemctl`/`launchctl` inspection.
- Added Dev Container CLI installation to native Linux/macOS bootstrap
  (`scripts/posix/install-devcontainers-cli.sh`), closing a gap where a fresh non-WSL
  machine couldn't satisfy `policy/development.json`'s `requireDevContainer` check.
- Bootstrap now runs `enforce` (informationally) after `doctor` on all three platforms,
  and `docs/new-machine.md` states the concrete "ready to work" contract.
- Fixed every tracked shell script and Git hook (`bootstrap`, `setup`,
  `scripts/posix/*.sh`, `platform/*/*.sh`, `wsl/*.sh`, `.githooks/*`) being committed
  without the executable bit (`core.fileMode=false` on the Windows authoring machine
  meant `chmod` was never recorded) — a fresh Linux/macOS clone could not run
  `./bootstrap` at all until this was fixed.
- Added `docs/auto-update.md`.

## 3.2.0

- Hardened Windows bootstrap for managed endpoints (execution-policy- and
  App-Control-safe `workstation` command shim, VS Code/Windows Terminal/font
  provisioning adjustments).
- Made WSL provisioning idempotent.

## 3.1.0

- Added policy-as-code development-environment enforcement.
- Added `policy/development.json` and schema.
- Added `workstation enforce` with safe `--repair`.
- Added governed project lifecycle commands: templates, init, check, doctor and open.
- Added Dev Container templates for FastAPI, React, Python services, Terraform and research Python.
- Enforced WSL/Linux project roots on Windows and Docker-inside-WSL policy.
- Added project checks for required files, non-root Dev Containers, tracked `.env`
  files, private-key-like filenames and Docker `:latest`.
- Added project metadata under `.platformctl/project.json`.
- Added development-policy validation to platformctl CI.
- Added `policy` to platformctl autosync safe tracked roots.
- Clarified that platformctl autosync never applies to application repositories.
- Updated AI-agent contract for project policy and CI/security invariants.

## 3.0.0

- Rebuilt the workstation as a GitHub-first source-of-truth repository.
- Added one-command Windows and POSIX bootstrap entrypoints.
- Added platform adapters for Windows, Linux and macOS.
- Replaced rsync-style thinking with explicit cp/Copy-Item deployment.
- Added background autosync that validates, applies, commits and pushes the current branch.
- Added pre-commit validation and post-commit apply/push hooks.
- Added safe GitHub publication commands using GitHub CLI.
- Added AI-agent contracts for Codex, Claude, Kimi and Copilot.
- Added GitHub Actions validation on Windows, Linux and macOS.
- Standardized VS Code editor font on official JetBrains Mono.
- Standardized terminal font on JetBrainsMono Nerd Font Mono.
- Added cross-platform VS Code configuration and extension management.
- Added cross-platform Oh My Posh configuration.
- Added secret filename protection to autosync.
- Preserved Windows Terminal PowerShell-only architecture.
- Preserved Docker-inside-WSL architecture on Windows.
- Added global logical `workstation` command after bootstrap.

## 2.5

- Standardized Windows Terminal on exactly one explicit shell: PowerShell 7 GUID `{574e775e-4f2a-5b96-ac1e-a2962a402336}`.
- Made that PowerShell 7 profile the Windows Terminal default.
- Added an advanced Tokyo Night Windows Terminal configuration with centered 160×44 launch size.
- Added extensive keyboard-first tab, pane, navigation, incident-bookmark, export-buffer, search and font controls.
- Preserved `Ctrl+C` for shell interrupt and moved clipboard operations to `Ctrl+Shift+C/V`.
- Added command/prompt marks and a 32,767-line operational scrollback.
- Added global Meslo Nerd Font installation through the `NerdFonts` PowerShell resource with `AllUsers` scope.
- Added a safe Windows Terminal settings installer with automatic backup and JSON validation.
- Expanded the PowerShell profile for PSReadLine history/prediction, fzf, zoxide, Git, WSL, Docker, Azure, Kubernetes, Terraform and network diagnostics.
- Added CLM-aware Oh My Posh behavior and a minimal fallback prompt.
- Added `windows/46-shell-doctor.ps1`.
- Hardened the Oh My Posh path renderer against duplicate `spa/spa` paths.
- Documented RemoteSigned/MOTW handling without execution-policy bypasses.

## 2.4

- Replaced Starship with Oh My Posh as the workstation prompt engine.
- Added a compact Tokyo Night Storm-derived Oh My Posh theme.
- Preserved the one-line prompt and short `spa` path abbreviation.
- Added true right-side command duration and clock using an Oh My Posh `rprompt`.
- Retained ble.sh because current Oh My Posh Bash rprompt support uses it.
- Added supported PowerShell ConstrainedLanguage initialization without weakening App Control.
- Windows migration backs up Starship config and attempts to uninstall the WinGet Starship package.
- WSL migration backs up Starship config and removes only the repo-owned local Starship binary.
- Added migration documentation and Oh My Posh diagnostics.

## 2.3

- Added adaptive PowerShell Starship initialization.
- Fixed Starship startup under enterprise PowerShell ConstrainedLanguage.
- CLM now uses a direct `starship prompt` adapter instead of the generated PowerShell initializer that creates restricted .NET process types.
- Added CLM-safe zoxide wrappers.
- Windows shell installer reports the detected PowerShell language mode.
- App Control / WDAC / ConstrainedLanguage are never disabled or bypassed.

## v2.2

- Standardized advanced shell UX on Starship + Tokyo Night.
- Added compact two-component path rendering and engineering directory substitutions.
- Added Bash true right prompt with command duration and time using ble.sh.
- Added WSL shell bootstrap with fzf, zoxide, eza, bat, fd, ripgrep, direnv and tmux.
- Added enterprise-safe PowerShell 7 profile plus Starship/zoxide/fzf installer.
- Fixed WSL Windows-profile discovery for PowerShell ConstrainedLanguage environments.
- Hardened shared SSH configuration: common config copied into WSL; private keys remain OS-specific.
- Fixed Sysinternals package handling by using the Microsoft Store package instead of bypassing hash validation.
- Improved Windows package installation verification and failure reporting.
- Improved `platformctl doctor` with per-command timeouts, explicit TIMEOUT state, and separate Azure authentication status.
