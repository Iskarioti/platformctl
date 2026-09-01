#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG="$ROOT/development/catalog.json"
NETWORK="platform-dev"
SECRET_ROOT="${PLATFORM_SERVICES_SECRET_ROOT:-$HOME/.config/workstation/services}"

usage() {
  cat <<'USAGE'
workstation services commands:
  init [service|profile ...]       create network + service-specific secret envs
  list                             show modular service catalog and profiles
  show <service>                   show service metadata
  path <service>                   print canonical service directory
  config <service>                 show resolved config file locations
  up [service|profile ...]         start targets; default profile is core
  pull [service|profile ...]       pull pinned images
  stop <service|profile ...>       stop targets
  restart <service|profile ...>    restart targets
  down                             stop/remove all catalog containers; keep volumes
  logs <service>                   follow one service
  status                           show all catalog containers
  doctor                           validate catalog/network/Compose/container health
  urls                             show host and Docker-network endpoints
  env <service>                    print secret env file path only
  project-up [path]                start services declared by project metadata
  reset <service> [--yes]          delete service container + its persistent volumes
USAGE
}

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "ERROR: required command missing: $1" >&2
    exit 2
  }
}

catalog_services() {
  python3 - "$CATALOG" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
for name in c["services"]:
    print(name)
PY
}

is_service() {
  python3 - "$CATALOG" "$1" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
raise SystemExit(0 if sys.argv[2] in c["services"] else 1)
PY
}

is_profile() {
  python3 - "$CATALOG" "$1" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
raise SystemExit(0 if sys.argv[2] in c["profiles"] else 1)
PY
}

service_dir() {
  python3 - "$CATALOG" "$1" "$ROOT" <<'PY'
import json, os, sys
c=json.load(open(sys.argv[1]))
name=sys.argv[2]
root=sys.argv[3]
try:
    print(os.path.join(root, c["services"][name]["path"]))
except KeyError:
    raise SystemExit(2)
PY
}

resolve_targets() {
  python3 - "$CATALOG" "$@" <<'PY'
import json, os, sys

catalog=json.load(open(sys.argv[1]))
targets=sys.argv[2:] or ["core"]

requested=[]
for target in targets:
    if target in catalog["profiles"]:
        requested.extend(catalog["profiles"][target])
    elif target in catalog["services"]:
        requested.append(target)
    else:
        print(f"ERROR: unknown service/profile: {target}", file=sys.stderr)
        raise SystemExit(2)

development_dir=os.path.dirname(sys.argv[1])
services_root=os.path.join(development_dir, "services")
seen=set()
ordered=[]

def visit(name):
    if name in seen:
        return
    meta_path=os.path.join(services_root, name, "service.json")
    meta=json.load(open(meta_path))
    for dep in meta.get("dependsOn", []):
        visit(dep)
    seen.add(name)
    ordered.append(name)

for name in requested:
    visit(name)

for name in ordered:
    print(name)
PY
}

strong_password() { printf 'Aa1!%s' "$(openssl rand -hex 18)"; }
randhex() { openssl rand -hex 24; }

ensure_docker() {
  need docker
  docker info >/dev/null 2>&1 || {
    echo "ERROR: Docker Engine is unavailable. Start Docker inside WSL." >&2
    exit 3
  }
}

ensure_network() {
  ensure_docker
  if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    docker network create --driver bridge --attachable "$NETWORK" >/dev/null
    echo "CREATED network $NETWORK"
  fi
}

secret_file() { printf '%s/%s.env\n' "$SECRET_ROOT" "$1"; }

generate_secret_file() {
  local service="$1"
  local file
  file="$(secret_file "$service")"

  case "$service" in
    postgres)
      [[ -f "$file" ]] || printf 'POSTGRES_PASSWORD=%s\n' "$(randhex)" > "$file"
      ;;
    pgadmin)
      [[ -f "$file" ]] || printf 'PGADMIN_DEFAULT_PASSWORD=%s\n' "$(randhex)" > "$file"
      ;;
    redis)
      [[ -f "$file" ]] || printf 'REDIS_PASSWORD=%s\n' "$(randhex)" > "$file"
      ;;
    redisinsight)
      [[ -f "$file" ]] || printf 'REDISINSIGHT_ENCRYPTION_KEY=%s\n' "$(randhex)" > "$file"
      ;;
    opensearch)
      [[ -f "$file" ]] || printf 'OPENSEARCH_INITIAL_ADMIN_PASSWORD=%s\n' "$(strong_password)" > "$file"
      ;;
    rabbitmq)
      [[ -f "$file" ]] || printf 'RABBITMQ_DEFAULT_PASS=%s\n' "$(randhex)" > "$file"
      ;;
    mongodb)
      [[ -f "$file" ]] || printf 'MONGO_INITDB_ROOT_PASSWORD=%s\n' "$(randhex)" > "$file"
      ;;
    minio)
      [[ -f "$file" ]] || printf 'MINIO_ROOT_PASSWORD=%s\n' "$(strong_password)" > "$file"
      ;;
    grafana)
      [[ -f "$file" ]] || printf 'GRAFANA_ADMIN_PASSWORD=%s\n' "$(strong_password)" > "$file"
      ;;
    qdrant)
      [[ -f "$file" ]] || printf 'QDRANT_API_KEY=%s\n' "$(randhex)" > "$file"
      ;;
    *)
      return 0
      ;;
  esac

  chmod 600 "$file"
}

ensure_secrets_for() {
  need openssl
  mkdir -p "$SECRET_ROOT"
  chmod 700 "$SECRET_ROOT" 2>/dev/null || true

  local s
  for s in "$@"; do
    generate_secret_file "$s"
  done
}

build_compose_args() {
  # Explicit --project-directory is required: Compose otherwise defaults the
  # project directory to the parent of the FIRST -f file, and resolves every
  # merged file's relative bind-mount sources against that single directory —
  # not each file's own directory. With more than one resolved service that
  # each declare their own "./config/..." mount, this silently cross-wires
  # sources onto whichever service came first (confirmed: it corrupted the
  # "core" profile's redis.conf mount). Every compose.yaml's relative volume
  # paths below are therefore written relative to $ROOT, not to their own
  # directory.
  COMPOSE_ARGS=(-p platform-dev --project-directory "$ROOT")
  local s dir meta secret
  for s in "$@"; do
    dir="$(service_dir "$s")"
    meta="$dir/service.json"

    COMPOSE_ARGS+=(--env-file "$dir/versions.env")
    COMPOSE_ARGS+=(--env-file "$dir/defaults.env")

    if python3 - "$meta" <<'PY'
import json, sys
m=json.load(open(sys.argv[1]))
raise SystemExit(0 if m.get("secretKeys") else 1)
PY
    then
      secret="$(secret_file "$s")"
      [[ -f "$secret" ]] && COMPOSE_ARGS+=(--env-file "$secret")
    fi
    COMPOSE_ARGS+=(-f "$dir/compose.yaml")
  done
}

compose_for() {
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$@")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"
  docker compose "${COMPOSE_ARGS[@]}" "${COMPOSE_COMMAND[@]}"
}

init_catalog() {
  ensure_network
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$@")
  ensure_secrets_for "${resolved[@]}"
  echo "Development service catalog initialized."
  echo "Network: $NETWORK"
  echo "Secrets: $SECRET_ROOT"
}

list_catalog() {
  python3 - "$CATALOG" <<'PY'
import json, sys
c=json.load(open(sys.argv[1]))
print("=== Modular Development Service Catalog ===")
print(f"Network: {c['network']}")
print(f"Version: {c['version']}")
print("\nServices:")
for name in c["services"]:
    print(f"  {name}")
print("\nProfiles:")
for name, members in c["profiles"].items():
    print(f"  {name:<12} {' '.join(members)}")
PY
}

show_service() {
  local s="${1:-}"
  is_service "$s" || { echo "Unknown service: $s" >&2; exit 2; }
  python3 -m json.tool "$(service_dir "$s")/service.json"
}

config_service() {
  local s="${1:-}"
  is_service "$s" || { echo "Unknown service: $s" >&2; exit 2; }
  local dir
  dir="$(service_dir "$s")"
  echo "Service:  $s"
  echo "Path:     $dir"
  echo "Compose:  $dir/compose.yaml"
  echo "Versions: $dir/versions.env"
  echo "Defaults: $dir/defaults.env"
  echo "Example:  $dir/.env.example"
  echo "Secrets:  $(secret_file "$s")"
}

up_catalog() {
  ensure_network
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$@")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"
  docker compose "${COMPOSE_ARGS[@]}" up -d
  docker compose "${COMPOSE_ARGS[@]}" ps
}

pull_catalog() {
  ensure_network
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$@")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"
  docker compose "${COMPOSE_ARGS[@]}" pull
}

all_compose_args() {
  local -a all
  mapfile -t all < <(catalog_services)
  ensure_secrets_for "${all[@]}"
  build_compose_args "${all[@]}"
}

status_catalog() {
  ensure_docker
  all_compose_args
  docker compose "${COMPOSE_ARGS[@]}" ps -a
}

down_catalog() {
  ensure_docker
  all_compose_args
  docker compose "${COMPOSE_ARGS[@]}" down
}

target_action() {
  local action="$1"
  shift
  [[ "$#" -gt 0 ]] || { echo "ERROR: target required." >&2; exit 2; }

  ensure_docker
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$@")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"

  case "$action" in
    stop) docker compose "${COMPOSE_ARGS[@]}" stop ;;
    restart) docker compose "${COMPOSE_ARGS[@]}" restart ;;
  esac
}

logs_service() {
  local s="${1:-}"
  is_service "$s" || { echo "Unknown service: $s" >&2; exit 2; }
  local -a resolved
  mapfile -t resolved < <(resolve_targets "$s")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"
  docker compose "${COMPOSE_ARGS[@]}" logs -f --tail 200 "$s"
}

show_urls() {
  local -a all
  mapfile -t all < <(catalog_services)
  ensure_secrets_for "${all[@]}"

  local s dir file
  set -a
  for s in "${all[@]}"; do
    dir="$(service_dir "$s")"
    # shellcheck disable=SC1090
    source "$dir/versions.env"
    # shellcheck disable=SC1090
    source "$dir/defaults.env"
    file="$(secret_file "$s")"
    [[ -f "$file" ]] && source "$file"
  done

  python3 - "$CATALOG" "$ROOT" <<'PY'
import json, os, re, sys

catalog=json.load(open(sys.argv[1]))
root=sys.argv[2]

pattern=re.compile(r"\$\{([A-Za-z_][A-Za-z0-9_]*)\}")
def expand(s):
    return pattern.sub(lambda m: os.environ.get(m.group(1), m.group(0)), s)

print("Windows / WSL localhost endpoints:")
for name in catalog["services"]:
    meta=json.load(open(os.path.join(root, "development", "services", name, "service.json")))
    for item in meta.get("hostEndpoints", []):
        print(f"  {item['label']:<24} {expand(item['endpoint'])}")

print("\nDev Container / Docker-network endpoints:")
for name in catalog["services"]:
    meta=json.load(open(os.path.join(root, "development", "services", name, "service.json")))
    for item in meta.get("dockerEndpoints", []):
        print(f"  {item['label']:<24} {expand(item['endpoint'])}")
PY

  echo
  echo "Runtime secrets are stored per service under: $SECRET_ROOT"
}

doctor_catalog() {
  local failures=0
  need python3

  if docker info >/dev/null 2>&1; then
    echo "PASS  Docker Engine"
  else
    echo "FAIL  Docker Engine"
    failures=$((failures+1))
  fi

  if docker network inspect "$NETWORK" >/dev/null 2>&1; then
    echo "PASS  $NETWORK network"
  else
    echo "FAIL  $NETWORK network"
    failures=$((failures+1))
  fi

  local -a all
  mapfile -t all < <(catalog_services)
  ensure_secrets_for "${all[@]}"
  build_compose_args "${all[@]}"

  if docker compose "${COMPOSE_ARGS[@]}" config >/dev/null; then
    echo "PASS  modular Compose merge"
  else
    echo "FAIL  modular Compose merge"
    failures=$((failures+1))
  fi

  echo
  docker compose "${COMPOSE_ARGS[@]}" ps -a || true

  [[ "$failures" -eq 0 ]] || exit 1
}

reset_service() {
  local s="${1:-}" confirm="${2:-}"
  is_service "$s" || { echo "Unknown service: $s" >&2; exit 2; }

  if [[ "$confirm" != "--yes" ]]; then
    printf 'Reset %s and permanently delete its local development data? [y/N] ' "$s"
    read -r answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Cancelled."; return 0; }
  fi

  local -a resolved
  mapfile -t resolved < <(resolve_targets "$s")
  ensure_secrets_for "${resolved[@]}"
  build_compose_args "${resolved[@]}"
  docker compose "${COMPOSE_ARGS[@]}" rm -sf "$s" >/dev/null 2>&1 || true

  local dir
  dir="$(service_dir "$s")"
  while IFS= read -r volume; do
    [[ -n "$volume" ]] || continue
    docker volume rm "$volume" >/dev/null 2>&1 || true
    echo "DELETED volume $volume"
  done < <(
    python3 - "$dir/service.json" <<'PY'
import json, sys
for v in json.load(open(sys.argv[1])).get("volumes", []):
    print(v)
PY
  )

  echo "Reset complete: $s"
}

project_up() {
  need jq
  local target="${1:-$PWD}"
  target="$(realpath "$target")"
  local meta="$target/.platformctl/project.json"
  [[ -f "$meta" ]] || { echo "ERROR: project metadata missing: $meta" >&2; exit 2; }

  mapfile -t declared < <(jq -r '.developmentServices[]? // empty' "$meta")
  [[ "${#declared[@]}" -gt 0 ]] || {
    echo "Project declares no shared development services."
    return 0
  }

  up_catalog "${declared[@]}"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  init) init_catalog "$@" ;;
  list) list_catalog ;;
  show) show_service "${1:-}" ;;
  path) service_dir "${1:-}" ;;
  config) config_service "${1:-}" ;;
  up) up_catalog "$@" ;;
  pull) pull_catalog "$@" ;;
  stop) target_action stop "$@" ;;
  restart) target_action restart "$@" ;;
  down) down_catalog ;;
  logs) logs_service "${1:-}" ;;
  status) status_catalog ;;
  doctor) doctor_catalog ;;
  urls) show_urls ;;
  env)
    is_service "${1:-}" || { echo "Unknown service: ${1:-}" >&2; exit 2; }
    secret_file "$1"
    ;;
  project-up) project_up "${1:-$PWD}" ;;
  reset) reset_service "${1:-}" "${2:-}" ;;
  help|-h|--help) usage ;;
  *) echo "Unknown services action: $ACTION" >&2; usage; exit 2 ;;
esac
