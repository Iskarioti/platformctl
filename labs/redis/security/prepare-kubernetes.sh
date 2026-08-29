#!/usr/bin/env bash
set -euo pipefail
STATE="${1:?state directory required}"
NS="${2:?namespace required}"

# shellcheck disable=SC1090
source "$STATE/.env"

kubectl -n "$NS" create secret generic redis-security-tls \
  --from-file=ca.crt="$STATE/certs/ca.crt" \
  --from-file=server.crt="$STATE/certs/server.crt" \
  --from-file=server.key="$STATE/certs/server.key" \
  --from-file=client.crt="$STATE/certs/client.crt" \
  --from-file=client.key="$STATE/certs/client.key" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create secret generic redis-security-acl \
  --from-file=users.acl="$STATE/users.acl" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n "$NS" create secret generic redis-security-auth \
  --from-literal=password="$REDIS_ADMIN_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -
