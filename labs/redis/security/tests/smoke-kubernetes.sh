#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-redis-security
kubectl wait --for=condition=available deployment/redis-security -n "$NS" --timeout=180s
POD="$(kubectl get pod -n "$NS" -l platformctl.lab=redis-security -o jsonpath='{.items[0].metadata.name}')"

kubectl exec -n "$NS" "$POD" -- sh -ec '
redis-cli --tls --cacert /certs/ca.crt \
  --cert /certs/client.crt --key /certs/client.key \
  --user admin --pass "$REDIS_ADMIN_PASSWORD" ping
' | grep -q PONG

if kubectl exec -n "$NS" "$POD" -- sh -ec '
redis-cli --tls --cacert /certs/ca.crt \
  --user admin --pass "$REDIS_ADMIN_PASSWORD" ping
' >/dev/null 2>&1; then
  echo "FAIL: Redis accepted a TLS client without required client certificate." >&2
  exit 1
fi

echo "PASS redis-security kubernetes mTLS + ACL"
