#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="platformctl-lab-agent-mesh:dev"
CLUSTER="platform-labs"

docker build -t "$IMAGE" "$ROOT/app"
k3d image import "$IMAGE" -c "$CLUSTER"
