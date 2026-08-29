#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-redis-cluster
kubectl delete pod redis-0 -n "$NS" --wait=false
kubectl wait --for=condition=ready pod/redis-0 -n "$NS" --timeout=180s
kubectl exec -n "$NS" redis-1 -- redis-cli cluster info | grep -q 'cluster_state:ok'
echo "PASS redis-cluster kubernetes pod-failure"
