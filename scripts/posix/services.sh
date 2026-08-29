#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMPOSE_FILE="$ROOT/development/services/compose.yaml"
VERSIONS_FILE="$ROOT/development/services/versions.env"
ENV_FILE="${PLATFORM_DEV_ENV:-$HOME/.config/workstation/dev-services.env}"
NETWORK="platform-dev"

SERVICES=(postgres pgbouncer redis kafka opensearch rabbitmq mongodb minio mailpit)
PROFILES=(core messaging search data integration all)

usage() {
  cat <<'USAGE'
workstation services commands:
  init                         create network and local credential file
  list                         show catalog, profiles and current status
  up [service|profile ...]     start selected services (default: core)
  stop <service ...>           stop selected services without deleting data
  down                         stop/remove catalog containers; preserve volumes
  restart <service ...>        restart selected services
  logs <service>               follow logs
  status                       show compose status
  doctor                       verify Docker/network and running health
  urls                         show localhost and Docker-network endpoints
  pull [service|profile ...]   pull pinned images
  env                          print local environment-file path only
  project-up [path]            start services declared by .platformctl/project.json
  reset <service> [--yes]      delete one service's persistent volume
USAGE
}

need() { command -v "$1" >/dev/null 2>&1 || { echo "ERROR: required command missing: $1" >&2; exit 2; }; }
is_service() {
  local x="$1" s
  for s in "${SERVICES[@]}"; do [[ "$x" == "$s" ]] && return 0; done
  return 1
}

is_profile() {
  local x="$1" p
  for p in "${PROFILES[@]}"; do [[ "$x" == "$p" ]] && return 0; done
  return 1
}

randhex() { openssl rand -hex 24; }
strong_password() { printf 'Aa1!%s' "$(openssl rand -hex 18)"; }
cluster_id() { openssl rand -base64 16 | tr '/+' '_-' | tr -d '=\n'; }

ensure_docker() {
  need docker
  docker info >/dev/null 2>&1 || {
    echo "ERROR: Docker Engine is unavailable. Start Docker inside WSL first." >&2
    exit 3
  }
}

ensure_network() {
  if ! docker network inspect "$NETWORK" >/dev/null 2>&1; then
    docker network create --driver bridge --attachable "$NETWORK" >/dev/null
    echo "CREATED network $NETWORK"
  fi
}

ensure_env() {
  need openssl
  if [[ -f "$ENV_FILE" ]]; then
    chmod 600 "$ENV_FILE" 2>/dev/null || true
    return 0
  fi

  mkdir -p "$(dirname "$ENV_FILE")"
  umask 077
  cat > "$ENV_FILE" <<ENV
POSTGRES_USER=platformdev
POSTGRES_PASSWORD=$(randhex)
POSTGRES_DB=platformdev
POSTGRES_HOST_PORT=5432
PGBOUNCER_HOST_PORT=6432

REDIS_PASSWORD=$(randhex)
REDIS_HOST_PORT=6379

KAFKA_CLUSTER_ID=$(cluster_id)
KAFKA_HOST_PORT=9092

OPENSEARCH_INITIAL_ADMIN_PASSWORD=$(strong_password)
OPENSEARCH_HOST_PORT=9200

RABBITMQ_DEFAULT_USER=platformdev
RABBITMQ_DEFAULT_PASS=$(randhex)
RABBITMQ_AMQP_HOST_PORT=5672
RABBITMQ_UI_HOST_PORT=15672

MONGO_INITDB_ROOT_USERNAME=platformdev
MONGO_INITDB_ROOT_PASSWORD=$(randhex)
MONGO_INITDB_DATABASE=platformdev
MONGO_HOST_PORT=27017

MINIO_ROOT_USER=platformdev
MINIO_ROOT_PASSWORD=$(strong_password)
MINIO_API_HOST_PORT=9000
MINIO_CONSOLE_HOST_PORT=9001

MAILPIT_SMTP_HOST_PORT=1025
MAILPIT_UI_HOST_PORT=8025
ENV
  chmod 600 "$ENV_FILE"
  echo "CREATED local credentials: $ENV_FILE"
}

compose() {
  docker compose \
    --env-file "$VERSIONS_FILE" \
    --env-file "$ENV_FILE" \
    -f "$COMPOSE_FILE" \
    "$@"
}

init_catalog() {
  ensure_docker
  ensure_network
  ensure_env
  echo "Development service catalog initialized."
  echo "Credentials: $ENV_FILE"
}

build_target_args() {
  TARGET_PROFILE_ARGS=()
  TARGET_SERVICE_ARGS=()
  local target
  for target in "$@"; do
    if is_profile "$target"; then
      TARGET_PROFILE_ARGS+=(--profile "$target")
    elif is_service "$target"; then
      TARGET_SERVICE_ARGS+=("$target")
    else
      echo "ERROR: unknown service/profile: $target" >&2
      exit 2
    fi
  done
}

status_catalog() {
  ensure_env
  compose ps -a
}

list_catalog() {
  echo "=== Development Service Catalog ==="
  echo "Network:     $NETWORK"
  echo "Credentials: $ENV_FILE"
  echo
  echo "Services:"
  printf '  %s\n' "${SERVICES[@]}"
  echo
  echo "Profiles:"
  echo "  core        postgres redis"
  echo "  messaging   kafka rabbitmq"
  echo "  search      opensearch"
  echo "  data        postgres pgbouncer mongodb"
  echo "  integration minio mailpit"
  echo "  all         all catalog services"
  echo
  if [[ -f "$ENV_FILE" ]] && docker info >/dev/null 2>&1; then compose ps -a || true; fi
}

up_catalog() {
  init_catalog
  if [[ "$#" -eq 0 ]]; then set -- core; fi
  build_target_args "$@"
  if [[ "${#TARGET_SERVICE_ARGS[@]}" -gt 0 ]]; then
    compose "${TARGET_PROFILE_ARGS[@]}" up -d "${TARGET_SERVICE_ARGS[@]}"
  else
    compose "${TARGET_PROFILE_ARGS[@]}" up -d
  fi
  compose ps
}

pull_catalog() {
  init_catalog
  if [[ "$#" -eq 0 ]]; then set -- core; fi
  build_target_args "$@"
  if [[ "${#TARGET_SERVICE_ARGS[@]}" -gt 0 ]]; then
    compose "${TARGET_PROFILE_ARGS[@]}" pull "${TARGET_SERVICE_ARGS[@]}"
  else
    compose "${TARGET_PROFILE_ARGS[@]}" pull
  fi
}

show_urls() {
  ensure_env
  # shellcheck disable=SC1090
  source "$ENV_FILE"
  cat <<URLS
Windows/WSL localhost endpoints:
  PostgreSQL   postgresql://${POSTGRES_USER}@127.0.0.1:${POSTGRES_HOST_PORT}/${POSTGRES_DB}
  PgBouncer    postgresql://${POSTGRES_USER}@127.0.0.1:${PGBOUNCER_HOST_PORT}/${POSTGRES_DB}
  Redis        redis://127.0.0.1:${REDIS_HOST_PORT}
  Kafka        127.0.0.1:${KAFKA_HOST_PORT}
  OpenSearch   https://127.0.0.1:${OPENSEARCH_HOST_PORT}
  RabbitMQ     amqp://127.0.0.1:${RABBITMQ_AMQP_HOST_PORT}
  RabbitMQ UI  http://127.0.0.1:${RABBITMQ_UI_HOST_PORT}
  MongoDB      mongodb://127.0.0.1:${MONGO_HOST_PORT}
  MinIO API    http://127.0.0.1:${MINIO_API_HOST_PORT}
  MinIO UI     http://127.0.0.1:${MINIO_CONSOLE_HOST_PORT}
  Mailpit SMTP 127.0.0.1:${MAILPIT_SMTP_HOST_PORT}
  Mailpit UI   http://127.0.0.1:${MAILPIT_UI_HOST_PORT}

Dev Container / Docker-network endpoints:
  PostgreSQL   dev-postgres:5432
  PgBouncer    dev-pgbouncer:5432
  Redis        dev-redis:6379
  Kafka        dev-kafka:29092
  OpenSearch   https://dev-opensearch:9200
  RabbitMQ     dev-rabbitmq:5672
  MongoDB      dev-mongodb:27017
  MinIO        dev-minio:9000
  Mailpit SMTP dev-mailpit:1025
URLS
  echo
  echo "Passwords are stored only in: $ENV_FILE"
}

service_volume() {
  case "$1" in
    postgres) echo platform-postgres-data ;;
    redis) echo platform-redis-data ;;
    kafka) echo platform-kafka-data ;;
    opensearch) echo platform-opensearch-data ;;
    rabbitmq) echo platform-rabbitmq-data ;;
    mongodb) echo platform-mongodb-data ;;
    minio) echo platform-minio-data ;;
    mailpit) echo platform-mailpit-data ;;
    pgbouncer) echo "" ;;
    *) return 1 ;;
  esac
}

reset_service() {
  init_catalog
  local service="${1:-}" confirm="${2:-}"
  [[ -n "$service" ]] || { echo "Usage: workstation services reset <service> [--yes]" >&2; exit 2; }
  is_service "$service" || { echo "Unknown service: $service" >&2; exit 2; }
  local volume
  volume="$(service_volume "$service")"
  if [[ -z "$volume" ]]; then
    echo "$service has no persistent catalog volume; removing its container only."
  fi
  if [[ "$confirm" != "--yes" ]]; then
    printf 'Reset %s and permanently delete its local development data? [y/N] ' "$service"
    read -r answer
    [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "Cancelled."; exit 0; }
  fi
  compose rm -sf "$service" >/dev/null 2>&1 || true
  if [[ -n "$volume" ]]; then
    docker volume rm "$volume" >/dev/null 2>&1 || true
    echo "DELETED volume $volume"
  fi
  echo "Reset complete: $service"
}

doctor_catalog() {
  local failures=0
  if docker info >/dev/null 2>&1; then echo "PASS  Docker Engine"; else echo "FAIL  Docker Engine"; failures=$((failures+1)); fi
  if docker network inspect "$NETWORK" >/dev/null 2>&1; then echo "PASS  $NETWORK network"; else echo "FAIL  $NETWORK network (run: workstation services init)"; failures=$((failures+1)); fi
  if [[ -f "$ENV_FILE" ]]; then echo "PASS  local credential file"; else echo "FAIL  local credential file (run: workstation services init)"; failures=$((failures+1)); fi

  if [[ -f "$ENV_FILE" ]] && docker info >/dev/null 2>&1; then
    echo
    compose ps -a
    echo
    local c health state
    while IFS= read -r c; do
      [[ -n "$c" ]] || continue
      state="$(docker inspect -f '{{.State.Status}}' "$c" 2>/dev/null || echo unknown)"
      health="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$c" 2>/dev/null || echo unknown)"
      if [[ "$state" == "running" && ( "$health" == "healthy" || "$health" == "none" ) ]]; then
        printf 'PASS  %-18s state=%s health=%s\n' "$c" "$state" "$health"
      elif [[ "$state" == "exited" || "$health" == "unhealthy" ]]; then
        printf 'FAIL  %-18s state=%s health=%s\n' "$c" "$state" "$health"
        failures=$((failures+1))
      else
        printf 'INFO  %-18s state=%s health=%s\n' "$c" "$state" "$health"
      fi
    done < <(compose ps -aq | xargs -r docker inspect -f '{{.Name}}' | sed 's#^/##')
  fi

  [[ "$failures" -eq 0 ]] || exit 1
}

project_up() {
  need jq
  local target="${1:-$PWD}"
  target="$(realpath "$target")"
  local meta="$target/.platformctl/project.json"
  [[ -f "$meta" ]] || { echo "ERROR: project metadata missing: $meta" >&2; exit 2; }
  mapfile -t declared < <(jq -r '.developmentServices[]? // empty' "$meta")
  if [[ "${#declared[@]}" -eq 0 ]]; then
    echo "Project declares no shared development services."
    exit 0
  fi
  echo "Project services: ${declared[*]}"
  up_catalog "${declared[@]}"
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  init) init_catalog ;;
  list) list_catalog ;;
  up) up_catalog "$@" ;;
  pull) pull_catalog "$@" ;;
  status) status_catalog ;;
  stop) ensure_env; compose stop "$@" ;;
  restart) ensure_env; compose restart "$@" ;;
  down) ensure_env; compose down ;;
  logs) ensure_env; [[ $# -eq 1 ]] || { echo "Usage: workstation services logs <service>" >&2; exit 2; }; compose logs -f --tail 200 "$1" ;;
  doctor) doctor_catalog ;;
  urls) show_urls ;;
  env) echo "$ENV_FILE" ;;
  project-up) project_up "${1:-$PWD}" ;;
  reset) reset_service "${1:-}" "${2:-}" ;;
  help|-h|--help) usage ;;
  *) echo "Unknown services action: $ACTION" >&2; usage; exit 2 ;;
esac
