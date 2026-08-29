#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG="$ROOT/labs/catalog.json"
STATE_ROOT="${PLATFORM_LAB_STATE_ROOT:-$HOME/.local/state/platformctl/labs}"

usage() {
  cat <<'USAGE'
workstation lab commands:
  list
  info <lab>
  toolchain install|doctor
  cluster create|status|delete
  up <lab> [--runtime docker|kubernetes]
  status <lab> [--runtime docker|kubernetes]
  logs <lab> [--runtime docker|kubernetes]
  test <lab> [test-name] [--runtime docker|kubernetes]
  stop <lab> [--runtime docker|kubernetes]
  destroy <lab> [--runtime docker|kubernetes] [--yes]
  report <lab> [--runtime docker|kubernetes]
USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command missing: $1" >&2
    exit 2
  }
}

lab_exists() {
  python3 - "$CATALOG" "$1" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
raise SystemExit(0 if sys.argv[2] in c["labs"] else 1)
PY
}

lab_dir() {
  python3 - "$CATALOG" "$1" "$ROOT" <<'PY'
import json, os, sys
c=json.load(open(sys.argv[1]))
print(os.path.join(sys.argv[3], c["labs"][sys.argv[2]]["path"]))
PY
}

lab_namespace() { printf 'platform-lab-%s\n' "$1"; }

parse_runtime() {
  RUNTIME="docker"
  REMAINING=()
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --runtime)
        RUNTIME="${2:-}"
        shift 2
        ;;
      --runtime=*)
        RUNTIME="${1#*=}"
        shift
        ;;
      *)
        REMAINING+=("$1")
        shift
        ;;
    esac
  done
  case "$RUNTIME" in
    docker|kubernetes) ;;
    *) echo "ERROR: runtime must be docker or kubernetes." >&2; exit 2 ;;
  esac
}

list_labs() {
  python3 - "$CATALOG" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
print("LAB                 RUNTIMES             TESTS                  PURPOSE")
for name, v in c["labs"].items():
    print(f"{name:<19} {','.join(v['runtimes']):<20} {','.join(v['tests']):<22} {v['purpose']}")
PY
}

info_lab() {
  local lab="${1:-}"
  lab_exists "$lab" || { echo "Unknown lab: $lab" >&2; exit 2; }
  python3 -m json.tool "$(lab_dir "$lab")/lab.json"
}

toolchain_doctor() {
  local fail=0
  for cmd in docker kubectl helm k3d openssl; do
    if command -v "$cmd" >/dev/null 2>&1; then
      printf 'PASS  %-12s %s\n' "$cmd" "$(command -v "$cmd")"
    else
      printf 'MISS  %-12s\n' "$cmd"
      [[ "$cmd" == docker || "$cmd" == kubectl || "$cmd" == k3d ]] && fail=$((fail+1))
    fi
  done
  [[ "$fail" -eq 0 ]] || return 1
}

cluster_name() {
  python3 - "$CATALOG" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["kubernetes"]["cluster"])
PY
}

k3s_image() {
  python3 - "$CATALOG" <<'PY'
import json, sys
print(json.load(open(sys.argv[1]))["kubernetes"]["k3sImage"])
PY
}

cluster_create() {
  need docker
  need k3d
  local name image
  name="$(cluster_name)"
  image="$(k3s_image)"

  if k3d cluster list -o json 2>/dev/null | python3 -c \
      'import json,sys; n=sys.argv[1]; raise SystemExit(0 if any(x.get("name")==n for x in json.load(sys.stdin)) else 1)' "$name"; then
    echo "Kubernetes lab cluster already exists: $name"
    return 0
  fi

  k3d cluster create "$name" \
    --image "$image" \
    --servers 1 \
    --agents 2 \
    --wait \
    --timeout 180s \
    --k3s-arg '--disable=traefik@server:*' \
    --k3s-arg '--disable=servicelb@server:*'

  echo "CREATED k3d cluster $name"
}

cluster_status() {
  need k3d
  k3d cluster list
  if command -v kubectl >/dev/null 2>&1; then
    kubectl get nodes -o wide 2>/dev/null || true
  fi
}

cluster_delete() {
  need k3d
  k3d cluster delete "$(cluster_name)"
}

prepare_lab() {
  local lab="$1"
  local dir state
  dir="$(lab_dir "$lab")"
  state="$STATE_ROOT/$lab"
  mkdir -p "$state"
  chmod 700 "$STATE_ROOT" "$state" 2>/dev/null || true

  if [[ -x "$dir/prepare.sh" ]]; then
    "$dir/prepare.sh" "$state"
  fi
}

docker_compose() {
  local lab="$1"
  shift
  local dir state
  dir="$(lab_dir "$lab")"
  state="$STATE_ROOT/$lab"
  export LAB_STATE_DIR="$state"

  local args=(-p "platform-lab-$lab")
  [[ -f "$state/.env" ]] && args+=(--env-file "$state/.env")
  args+=(-f "$dir/docker/compose.yaml")

  docker compose "${args[@]}" "$@"
}

kube_apply() {
  local lab="$1"
  local dir ns state
  dir="$(lab_dir "$lab")"
  ns="$(lab_namespace "$lab")"
  state="$STATE_ROOT/$lab"

  cluster_create
  kubectl create namespace "$ns" --dry-run=client -o yaml | kubectl apply -f -

  if [[ -x "$dir/prepare-kubernetes.sh" ]]; then
    "$dir/prepare-kubernetes.sh" "$state" "$ns"
  fi

  kubectl apply -k "$dir/kubernetes"
}

up_lab() {
  local lab="$1"
  shift
  lab_exists "$lab" || { echo "Unknown lab: $lab" >&2; exit 2; }
  parse_runtime "$@"
  prepare_lab "$lab"

  case "$RUNTIME" in
    docker)
      need docker
      docker_compose "$lab" up -d
      docker_compose "$lab" ps
      ;;
    kubernetes)
      need kubectl
      need k3d
      kube_apply "$lab"
      kubectl get all -n "$(lab_namespace "$lab")"
      ;;
  esac
}

status_lab() {
  local lab="$1"
  shift
  parse_runtime "$@"
  case "$RUNTIME" in
    docker) docker_compose "$lab" ps -a ;;
    kubernetes) kubectl get all -n "$(lab_namespace "$lab")" ;;
  esac
}

logs_lab() {
  local lab="$1"
  shift
  parse_runtime "$@"
  case "$RUNTIME" in
    docker) docker_compose "$lab" logs -f --tail 200 ;;
    kubernetes)
      kubectl logs -n "$(lab_namespace "$lab")" \
        -l "platformctl.lab=$lab" \
        --all-containers=true --tail=200 -f
      ;;
  esac
}

test_lab() {
  local lab="$1"
  shift
  lab_exists "$lab" || { echo "Unknown lab: $lab" >&2; exit 2; }

  parse_runtime "$@"
  local test_name="smoke"
  [[ "${#REMAINING[@]}" -gt 0 ]] && test_name="${REMAINING[0]}"

  local script
  script="$(lab_dir "$lab")/tests/${test_name}-${RUNTIME}.sh"
  [[ -x "$script" ]] || {
    echo "ERROR: test not implemented: $test_name ($RUNTIME)" >&2
    exit 2
  }

  export LAB_STATE_DIR="$STATE_ROOT/$lab"
  "$script"
}

stop_lab() {
  local lab="$1"
  shift
  parse_runtime "$@"
  case "$RUNTIME" in
    docker) docker_compose "$lab" stop ;;
    kubernetes)
      echo "Kubernetes labs are namespace-scoped; use destroy to remove this lab."
      ;;
  esac
}

destroy_lab() {
  local lab="$1"
  shift
  local yes=0
  local args=()
  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      --yes) yes=1; shift ;;
      *) args+=("$1"); shift ;;
    esac
  done
  parse_runtime "${args[@]}"

  if [[ "$yes" -ne 1 ]]; then
    printf 'Destroy lab %s (%s) and its disposable data? [y/N] ' "$lab" "$RUNTIME"
    read -r answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Cancelled."; return 0; }
  fi

  case "$RUNTIME" in
    docker) docker_compose "$lab" down -v --remove-orphans ;;
    kubernetes) kubectl delete namespace "$(lab_namespace "$lab")" --ignore-not-found ;;
  esac
}

report_lab() {
  local lab="$1"
  shift
  parse_runtime "$@"
  local dir out stamp
  dir="$(lab_dir "$lab")"
  stamp="$(date -u +%Y%m%dT%H%M%SZ)"
  out="$ROOT/.state/labs/$lab/reports/$stamp"
  mkdir -p "$out"

  {
    echo "lab=$lab"
    echo "runtime=$RUNTIME"
    echo "generated=$stamp"
    echo "host=$(hostname)"
  } > "$out/manifest.txt"

  (
    cd "$dir"
    find . -type f ! -path './.state/*' -print0 |
      sort -z |
      xargs -0 sha256sum
  ) > "$out/configuration-hashes.txt"

  case "$RUNTIME" in
    docker)
      docker_compose "$lab" ps -a > "$out/docker-ps.txt" 2>&1 || true
      docker_compose "$lab" images > "$out/docker-images.txt" 2>&1 || true
      ;;
    kubernetes)
      local ns
      ns="$(lab_namespace "$lab")"
      kubectl get all -n "$ns" -o wide > "$out/kubernetes-resources.txt" 2>&1 || true
      kubectl get events -n "$ns" --sort-by=.lastTimestamp > "$out/kubernetes-events.txt" 2>&1 || true
      kubectl get nodes -o wide > "$out/kubernetes-nodes.txt" 2>&1 || true
      ;;
  esac

  echo "Report: $out"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  list) list_labs ;;
  info) info_lab "${1:-}" ;;
  toolchain)
    sub="${1:-doctor}"
    case "$sub" in
      install) exec "$ROOT/scripts/posix/install-lab-toolchain.sh" ;;
      doctor) toolchain_doctor ;;
      *) echo "toolchain: install | doctor" >&2; exit 2 ;;
    esac
    ;;
  cluster)
    sub="${1:-status}"
    case "$sub" in
      create) cluster_create ;;
      status) cluster_status ;;
      delete) cluster_delete ;;
      *) echo "cluster: create | status | delete" >&2; exit 2 ;;
    esac
    ;;
  up) up_lab "${1:?lab required}" "${@:2}" ;;
  status) status_lab "${1:?lab required}" "${@:2}" ;;
  logs) logs_lab "${1:?lab required}" "${@:2}" ;;
  test) test_lab "${1:?lab required}" "${@:2}" ;;
  stop) stop_lab "${1:?lab required}" "${@:2}" ;;
  destroy) destroy_lab "${1:?lab required}" "${@:2}" ;;
  report) report_lab "${1:?lab required}" "${@:2}" ;;
  help|-h|--help) usage ;;
  *) echo "Unknown lab action: $ACTION" >&2; usage; exit 2 ;;
esac
