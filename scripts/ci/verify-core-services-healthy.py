"""Assert exactly 2 containers (postgres + redis, the "core" profile) are
running and healthy, from a `docker compose ps -a --format json` dump at the
path given as argv[1]. Regression check for the project-directory Compose
merge bug documented in .github/workflows/behavioral-tests.yml.
"""
import json
import sys

path = sys.argv[1]
lines = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
assert len(lines) == 2, f"expected 2 containers, got {len(lines)}: {lines}"
for c in lines:
    assert c["State"] == "running", c
    assert c.get("Health") in ("healthy", ""), c
print("OK: core dev services healthy - regression check for the project-directory Compose bug")
