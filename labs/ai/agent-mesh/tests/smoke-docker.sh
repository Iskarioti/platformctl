#!/usr/bin/env bash
set -euo pipefail
NET=platform-lab-agent-mesh

read -r -d '' PYCODE <<'PY' || true
import json
import urllib.request

for node in ("agent-1", "agent-2", "agent-3"):
    req = urllib.request.Request(
        f"http://{node}:8000/invoke?question=Say+hello+in+three+words.", method="POST"
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        body = json.loads(r.read())
    assert body["node"] == node, body
    assert body["answer"], body
    print(f"{node}: {body['answer']!r}")
PY

docker run --rm --network "$NET" python:3.13.15-slim-bookworm python3 -c "$PYCODE"
echo "PASS agent-mesh docker smoke"
