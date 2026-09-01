#!/usr/bin/env bash
set -euo pipefail
NET=platform-lab-agent-mesh

invoke() {
  docker run --rm --network "$NET" curlimages/curl:8.21.0 -sf --max-time 60 \
    -X POST "http://$1:8000/invoke?question=Say%20hello%20in%20three%20words."
}

echo "-- baseline: all three nodes respond --"
invoke agent-1 >/dev/null
invoke agent-2 >/dev/null
invoke agent-3 >/dev/null
echo "baseline ok"

echo "-- stopping agent-2 --"
docker stop lab-agent-2 >/dev/null

echo "-- confirm remaining nodes still serve while agent-2 is down --"
invoke agent-1 >/dev/null
invoke agent-3 >/dev/null
echo "remaining nodes ok"

echo "-- restarting agent-2 --"
docker start lab-agent-2 >/dev/null
for _ in $(seq 1 30); do
  docker run --rm --network "$NET" curlimages/curl:8.21.0 -sf --max-time 5 \
    http://agent-2:8000/health >/dev/null 2>&1 && break
  sleep 2
done
invoke agent-2 >/dev/null
echo "PASS agent-mesh docker node-failure"
