#!/usr/bin/env bash
set -euo pipefail
STATE="${LAB_STATE_DIR:?LAB_STATE_DIR required}"
# shellcheck disable=SC1090
source "$STATE/.env"

docker exec lab-redis-security redis-cli \
  --tls --cacert /certs/ca.crt \
  --cert /certs/client.crt --key /certs/client.key \
  --user admin --pass "$REDIS_ADMIN_PASSWORD" ping | grep -q PONG

if docker exec lab-redis-security redis-cli \
  --tls --cacert /certs/ca.crt \
  --user admin --pass "$REDIS_ADMIN_PASSWORD" ping >/dev/null 2>&1; then
  echo "FAIL: Redis accepted a TLS client without required client certificate." >&2
  exit 1
fi

echo "PASS redis-security docker mTLS + ACL"
