#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-rag-pipeline

# Deployment + emptyDir here (matching redis-cluster's kubernetes lab convention):
# this test proves the service recovers after a pod is lost, not data survival -
# the docker variant of this test proves data survival instead, since it uses a
# real named volume.
OLD_POD="$(kubectl get pod -n "$NS" -l app=qdrant -o jsonpath='{.items[0].metadata.name}')"
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false
kubectl wait --for=condition=available deployment/qdrant -n "$NS" --timeout=180s

read -r -d '' PYCODE <<'PY' || true
import json
import urllib.request

req = urllib.request.Request("http://qdrant:6333/collections", method="GET")
with urllib.request.urlopen(req, timeout=30) as r:
    body = json.loads(r.read())
assert "result" in body, body
print("qdrant reachable again after pod replacement")
PY

kubectl run rag-outage-probe -n "$NS" --rm -i --restart=Never \
  --image=python:3.13.15-slim-bookworm --command -- python3 -c "$PYCODE"
echo "PASS rag-pipeline kubernetes qdrant-outage"
