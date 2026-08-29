#!/usr/bin/env bash
set -euo pipefail
docker exec lab-redis-1 redis-cli cluster info | grep -q 'cluster_state:ok'
docker exec lab-redis-1 redis-cli -c set platformctl:lab ok >/dev/null
[[ "$(docker exec lab-redis-2 redis-cli -c get platformctl:lab | tr -d '\r')" == "ok" ]]
echo "PASS redis-cluster docker smoke"
