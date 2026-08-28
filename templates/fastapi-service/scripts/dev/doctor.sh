#!/usr/bin/env bash
set -euo pipefail
cd /workspace

echo "Python: $(python --version)"
echo "uv: $(uv --version)"

for i in $(seq 1 30); do
  if pg_isready -h postgres -U developer -d application >/dev/null 2>&1; then
    echo "PostgreSQL: ready"
    break
  fi
  sleep 1
done

redis-cli -h redis ping
