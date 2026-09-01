#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-rag-pipeline

kubectl wait --for=condition=complete job/model-pull -n "$NS" --timeout=600s

read -r -d '' PYCODE <<'PY' || true
import json
import urllib.error
import urllib.request


def request(url, payload=None, method=None):
    data = json.dumps(payload).encode() if payload is not None else None
    req = urllib.request.Request(
        url, data=data, headers={"Content-Type": "application/json"}, method=method
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def ensure_collection(url, payload):
    # a k8s-recreated qdrant pod uses a fresh emptyDir, but a pod that never
    # restarted (e.g. re-running this test in the same lab session) already
    # has the collection - tolerate that instead of failing on 409.
    try:
        request(url, payload, method="PUT")
    except urllib.error.HTTPError as e:
        if e.code != 409:
            raise


def embed(text):
    r = request("http://ollama:11434/api/embeddings", {"model": "nomic-embed-text", "prompt": text})
    return r["embedding"]


FACT = "platformctl labs validate architecture before it reaches production"

ensure_collection("http://qdrant:6333/collections/lab-rag", {"vectors": {"size": 768, "distance": "Cosine"}})

vec = embed(FACT)
request(
    "http://qdrant:6333/collections/lab-rag/points?wait=true",
    {"points": [{"id": 1, "vector": vec, "payload": {"text": FACT}}]},
    method="PUT",
)

qvec = embed("What do platformctl labs validate?")
result = request(
    "http://qdrant:6333/collections/lab-rag/points/search",
    {"vector": qvec, "limit": 1, "with_payload": True},
    method="POST",
)
top = result["result"][0]
assert top["payload"]["text"] == FACT, top
assert top["score"] > 0.5, top
print(f"retrieval ok, score={top['score']:.4f}")
PY

kubectl run rag-smoke-probe -n "$NS" --rm -i --restart=Never \
  --image=python:3.13.15-slim-bookworm --command -- python3 -c "$PYCODE"
echo "PASS rag-pipeline kubernetes smoke"
