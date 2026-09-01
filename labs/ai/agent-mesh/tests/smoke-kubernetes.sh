#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-agent-mesh

kubectl wait --for=condition=complete job/model-pull -n "$NS" --timeout=600s
kubectl wait --for=condition=available deployment/agent -n "$NS" --timeout=180s

for i in 1 2 3; do
  kubectl run agent-smoke-probe-$i -n "$NS" --rm -i --restart=Never \
    --image=curlimages/curl:8.21.0 --command -- \
    curl -sf --max-time 60 -X POST "http://agent:8000/invoke?question=Say+hello+in+three+words."
  echo
done
echo "PASS agent-mesh kubernetes smoke"
