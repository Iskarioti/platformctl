#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CATALOG="$ROOT/development/catalog.json"

# Compares what's actually running on this machine against what
# development/catalog.json declares - the architecture assumes git is the
# source of truth (docs/adr/), but nothing previously verified a machine's
# live state actually matches it. Two kinds of drift:
#   1. a running dev-* container whose image:version doesn't match its own
#      versions.env (someone bypassed "workstation services up", or pulled/
#      ran a different tag by hand)
#   2. a running dev-* container with no matching catalog service at all
#      (leftover from a renamed/removed service, or something started
#      outside this catalog entirely)
# This only inspects what's currently running - a catalog service that's
# simply not started isn't drift, it's just not up.

command -v docker >/dev/null 2>&1 || { echo "ERROR: docker is required." >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "ERROR: python3 is required." >&2; exit 2; }

RUNNING_JSON="$(docker ps --filter "name=^dev-" --format '{{json .}}' | python3 -c '
import json, sys
rows = [json.loads(line) for line in sys.stdin if line.strip()]
print(json.dumps(rows))
')"

python3 - "$ROOT" "$CATALOG" "$RUNNING_JSON" <<'PY'
import json
import sys
from pathlib import Path

root = Path(sys.argv[1])
catalog = json.loads(Path(sys.argv[2]).read_text())
running = json.loads(sys.argv[3])

services_root = root / catalog["servicesRoot"]

# container_name -> service id, for every service.json this catalog knows
# about, including multi-container services (e.g. langfuse's worker/init
# containers) whose own container_name isn't the catalog id.
container_to_service = {}
service_image_version = {}
for name in catalog["services"]:
    meta_path = services_root / name / "service.json"
    if not meta_path.exists():
        continue
    meta = json.loads(meta_path.read_text())
    versions_path = services_root / name / meta.get("versions", "versions.env")
    env = {}
    if versions_path.exists():
        for line in versions_path.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            k, v = line.split("=", 1)
            env[k] = v
    compose_path = services_root / name / meta.get("compose", "compose.yaml")
    compose_text = compose_path.read_text() if compose_path.exists() else ""
    for line in compose_text.splitlines():
        line = line.strip()
        if line.startswith("container_name:"):
            container_name = line.split(":", 1)[1].strip()
            container_to_service[container_name] = name
        if line.startswith("image:"):
            image_ref = line.split(":", 1)[1].strip()
            for k, v in env.items():
                image_ref = image_ref.replace("${" + k + "}", v).replace("${" + k + ":-" + v + "}", v)
            # container_name may appear before or after image: in the file;
            # this second pass after the full scan is what actually matters.
            service_image_version.setdefault(name, []).append(image_ref)

drift_found = False
undeclared = []
mismatched = []
clean = []


def _norm(ref: str) -> str:
    # Docker normalizes away the implicit "docker.io/" registry prefix in
    # "docker ps"'s own Image field (confirmed live: a compose.yaml's
    # "docker.io/langfuse/langfuse:4.27.0" shows up as plain
    # "langfuse/langfuse:4.27.0" here) - compare both sides with it
    # stripped, or every image pinned with an explicit "docker.io/" prefix
    # falsely reports as drifted.
    return ref[len("docker.io/"):] if ref.startswith("docker.io/") else ref


for c in running:
    cname = c["Names"]
    service = container_to_service.get(cname)
    if service is None:
        undeclared.append(cname)
        drift_found = True
        continue
    declared_refs = service_image_version.get(service, [])
    actual_ref = c["Image"]
    if declared_refs and _norm(actual_ref) not in [_norm(r) for r in declared_refs]:
        mismatched.append((cname, service, actual_ref, declared_refs))
        drift_found = True
    else:
        clean.append((cname, service))

for cname, service in clean:
    print(f"PASS  {cname:<28} matches declared image for '{service}'")

for cname, service, actual_ref, declared_refs in mismatched:
    print(f"WARN  {cname:<28} running {actual_ref}, catalog declares {' or '.join(declared_refs)} for '{service}'")

for cname in undeclared:
    print(f"WARN  {cname:<28} running but not in development/catalog.json at all")

print()
if drift_found:
    print(f"DRIFT DETECTED: {len(mismatched)} version mismatch(es), {len(undeclared)} undeclared container(s)")
else:
    print(f"No drift: {len(clean)} running dev-service container(s) all match development/catalog.json")

sys.exit(1 if drift_found else 0)
PY
