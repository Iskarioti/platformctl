#!/usr/bin/env bash
set -euo pipefail
docker stop lab-redis-1 >/dev/null
trap 'docker start lab-redis-1 >/dev/null 2>&1 || true' EXIT
sleep 8
docker exec lab-redis-2 redis-cli cluster info | grep -q 'cluster_state:ok'
docker start lab-redis-1 >/dev/null
trap - EXIT
echo "PASS redis-cluster docker failover"
