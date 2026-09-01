#!/usr/bin/env bash
set -euo pipefail
NET=platform-lab-rag-pipeline

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
    # the lab's qdrant volume survives "lab up"/"lab down" cycles (only "lab
    # destroy" clears it), so re-running this test against a lab left up from
    # a prior run must tolerate the collection already existing.
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

docker run --rm --network "$NET" python:3.13.15-slim-bookworm python3 -c "$PYCODE"
echo "PASS rag-pipeline docker smoke"
