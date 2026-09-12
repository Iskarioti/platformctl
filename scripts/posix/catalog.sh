#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

usage() {
  cat <<'USAGE'
workstation catalog commands:
  stats    summarize which project templates and dev-services actually get
           used, from .state/usage.jsonl (a real gap the Platform Engineer
           role review found: no data existed to answer "is this template
           worth keeping")
  costs    illustrative "if this ran as managed cloud infra instead" monthly
           estimate, sized from what's actually running right now - a rough
           FinOps signal for deciding what's worth productionizing, not a
           real quote (see the command's own output for the caveat)
USAGE
}

catalog_stats() {
  local log="$ROOT/.state/usage.jsonl"
  if [[ ! -f "$log" ]]; then
    echo "No usage recorded yet - .state/usage.jsonl doesn't exist."
    echo "It's written to by 'workstation project init' and 'workstation services up'."
    return 0
  fi

  python3 - "$log" <<'PY'
import json, sys
from collections import Counter

templates = Counter()
services = Counter()

for line in open(sys.argv[1], encoding="utf-8"):
    line = line.strip()
    if not line:
        continue
    event = json.loads(line)
    if event.get("event") == "project_init":
        templates[event.get("template", "?")] += 1
    elif event.get("event") == "services_up":
        for target in event.get("targets", "").split():
            services[target] += 1

print("=== Project templates ===")
if templates:
    for name, count in templates.most_common():
        print(f"{count:>4}  {name}")
else:
    print("(none recorded yet)")

print()
print("=== Services / profiles requested via 'services up' ===")
if services:
    for name, count in services.most_common():
        print(f"{count:>4}  {name}")
else:
    print("(none recorded yet)")
PY
}

catalog_costs() {
  command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required for 'catalog costs'." >&2; exit 2; }

  local -a names limits
  local line name mem
  while IFS=$'\t' read -r name mem; do
    [[ -n "$name" ]] || continue
    names+=("$name")
    limits+=("$mem")
  done < <(docker ps --filter "name=^dev-" --format '{{.Names}}' | while read -r c; do
    printf '%s\t%s\n' "$c" "$(docker inspect --format '{{.HostConfig.Memory}}' "$c" 2>/dev/null || echo 0)"
  done)

  if [[ "${#names[@]}" -eq 0 ]]; then
    echo "No dev-* containers currently running - nothing to estimate."
    echo "Run 'workstation services up <profile>' first, then re-run this."
    return 0
  fi

  python3 - "${names[@]}" -- "${limits[@]}" <<'PY'
import sys

args = sys.argv[1:]
sep = args.index("--")
names = args[:sep]
limits = args[sep + 1:]

# Illustrative only: a round $/GB-month figure loosely in the range of
# common managed container/database memory pricing in 2026, not tied to any
# specific cloud vendor's real rate card. This estimates relative SIZE
# ("does my active stack look like a $40/month footprint or a $4,000/month
# one"), not a quote - always check the real target platform's pricing
# before using this for an actual budget decision.
RATE_PER_GB_MONTH = 5.0

total_bytes = 0
rows = []
for name, mem in zip(names, limits):
    mem_bytes = int(mem) if mem.isdigit() else 0
    total_bytes += mem_bytes
    rows.append((name, mem_bytes))

print("=== Running dev-services (memory-limit sizing) ===")
for name, mem_bytes in sorted(rows, key=lambda r: -r[1]):
    gb = mem_bytes / (1024 ** 3)
    if mem_bytes == 0:
        print(f"{'unbounded':>10}  {name}  (no mem_limit set - excluded from the estimate below)")
    else:
        print(f"{gb:>8.2f} GB  {name}")

sized_bytes = sum(m for _, m in rows if m > 0)
total_gb = sized_bytes / (1024 ** 3)
monthly = total_gb * RATE_PER_GB_MONTH

print()
print(f"Total sized memory: {total_gb:.2f} GB across {sum(1 for _, m in rows if m > 0)} service(s)")
print(f"Illustrative managed-cloud equivalent: ~${monthly:.0f}/month at ${RATE_PER_GB_MONTH:.2f}/GB-month")
print()
print("This is a rough sizing signal, not a quote - it ignores compute/CPU,")
print("egress, storage IOPS, HA/replica multipliers, and your actual cloud")
print("provider's real pricing. Use it to decide what's worth a real costed")
print("proposal before productionizing, not as the proposal itself.")
PY
}

ACTION="${1:-help}"
shift || true

case "$ACTION" in
  stats) catalog_stats ;;
  costs) catalog_costs ;;
  help|-h|--help) usage ;;
  *) echo "Unknown catalog action: $ACTION" >&2; usage >&2; exit 2 ;;
esac
