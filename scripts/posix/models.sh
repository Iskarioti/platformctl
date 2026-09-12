#!/usr/bin/env bash
set -euo pipefail

# Wires ai-runtime/ (a shared Ollama runtime for local model testing - not a
# per-project Dev Container, not one of development/services/*'s dev-services
# either, since it's infrastructure every project borrows rather than a
# service any one project owns) into the "workstation" CLI. Previously this
# was Taskfile-only (ai-runtime/Taskfile.yml), invisible to anyone who didn't
# already know it existed - this script absorbs the same command set.
#
# On a memory-constrained laptop, switch to the ai-lab WSL profile
# (wsl/profiles/ai-lab.wslconfig: more RAM/swap) before pulling/running larger
# models - see that profile and windows/25-set-wsl-profile.ps1.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIR="$ROOT/ai-runtime"
set -a
source "$DIR/versions.env"
set +a

usage() {
  cat <<'USAGE'
workstation models commands:
  up                start the shared Ollama runtime (creates required networks)
  down               stop and remove the runtime
  status             show container status and reachable models
  pull <model>       pull a model (e.g. gemma3:1b, gemma3:4b, gemma3:12b)
  list               list models already pulled
  run <model>        open an interactive chat session with a model
USAGE
}

ensure_network() {
  local name="$1"
  docker network inspect "$name" >/dev/null 2>&1 || docker network create --driver bridge --attachable "$name" >/dev/null
}

compose() {
  docker compose -f "$DIR/compose.yaml" "$@"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  up)
    ensure_network ai-runtime
    ensure_network platform-dev
    compose up -d
    compose ps
    ;;
  down)
    compose down
    ;;
  status)
    compose ps
    curl -fsS http://127.0.0.1:11434/api/tags | jq .
    ;;
  pull)
    MODEL="${1:?Usage: workstation models pull <model>}"
    compose exec ollama ollama pull "$MODEL"
    ;;
  list)
    compose exec ollama ollama list
    ;;
  run)
    MODEL="${1:?Usage: workstation models run <model>}"
    compose exec ollama ollama run "$MODEL"
    ;;
  *)
    usage
    ;;
esac
