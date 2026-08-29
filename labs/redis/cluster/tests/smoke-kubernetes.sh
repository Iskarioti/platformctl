#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-redis-cluster
kubectl wait --for=condition=complete job/redis-cluster-init -n "$NS" --timeout=180s
kubectl exec -n "$NS" redis-0 -- redis-cli cluster info | grep -q 'cluster_state:ok'
kubectl exec -n "$NS" redis-0 -- redis-cli -c set platformctl:lab ok >/dev/null
echo "PASS redis-cluster kubernetes smoke"
