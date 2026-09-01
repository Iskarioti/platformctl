#!/usr/bin/env bash
set -euo pipefail
NS=platform-lab-agent-mesh

OLD_POD="$(kubectl get pod -n "$NS" -l app=agent -o jsonpath='{.items[0].metadata.name}')"
kubectl delete pod "$OLD_POD" -n "$NS" --wait=false

# the mesh should keep serving via its remaining replicas while the deleted pod
# is replaced - this is what "no single point of failure" actually means here.
kubectl run agent-failure-probe -n "$NS" --rm -i --restart=Never \
  --image=curlimages/curl:8.21.0 --command -- \
  curl -sf --max-time 60 -X POST "http://agent:8000/invoke?question=Say+hello+in+three+words."
echo

kubectl wait --for=condition=available deployment/agent -n "$NS" --timeout=180s
echo "PASS agent-mesh kubernetes node-failure"
