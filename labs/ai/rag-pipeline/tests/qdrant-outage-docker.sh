#!/usr/bin/env bash
set -euo pipefail
NET=platform-lab-rag-pipeline

read -r -d '' SEED_PY <<'PY' || true
import json
import urllib.error
import urllib.request


def request(url, payload, method):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"}, method=method
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


try:
    request("http://qdrant:6333/collections/lab-rag-outage", {"vectors": {"size": 4, "distance": "Cosine"}}, "PUT")
except urllib.error.HTTPError as e:
    if e.code != 409:
        raise
request(
    "http://qdrant:6333/collections/lab-rag-outage/points?wait=true",
    {"points": [{"id": 1, "vector": [0.1, 0.2, 0.3, 0.4], "payload": {"marker": "survives-restart"}}]},
    "PUT",
)
print("seeded")
PY

docker run --rm --network "$NET" python:3.13.15-slim-bookworm python3 -c "$SEED_PY"

echo "-- stopping qdrant --"
docker stop lab-rag-qdrant >/dev/null

STATUS="$(docker run --rm --network "$NET" curlimages/curl:8.21.0 \
  -s -o /dev/null -w '%{http_code}' --max-time 5 http://qdrant:6333/healthz)" || true
if [[ "$STATUS" != "000" ]]; then
  echo "ERROR: expected qdrant unreachable while stopped, got status $STATUS" >&2
  docker start lab-rag-qdrant >/dev/null
  exit 1
fi
echo "confirmed unreachable while stopped (status=$STATUS)"

echo "-- restarting qdrant --"
docker start lab-rag-qdrant >/dev/null

healthy=""
for _ in $(seq 1 30); do
  healthy="$(docker inspect --format '{{.State.Health.Status}}' lab-rag-qdrant 2>/dev/null || true)"
  [[ "$healthy" == "healthy" ]] && break
  sleep 1
done
[[ "$healthy" == "healthy" ]] || { echo "ERROR: qdrant did not become healthy again after restart" >&2; exit 1; }

read -r -d '' VERIFY_PY <<'PY' || true
import json
import urllib.request

req = urllib.request.Request("http://qdrant:6333/collections/lab-rag-outage/points/1")
with urllib.request.urlopen(req, timeout=30) as r:
    body = json.loads(r.read())
assert body["result"]["payload"]["marker"] == "survives-restart", body
print("data survived restart")
PY

docker run --rm --network "$NET" python:3.13.15-slim-bookworm python3 -c "$VERIFY_PY"
echo "PASS rag-pipeline docker qdrant-outage"
