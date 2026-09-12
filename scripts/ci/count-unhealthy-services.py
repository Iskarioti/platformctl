"""Count containers from a `docker compose ps -a --format json` dump
(one JSON object per line, at the path given as argv[1]) that are not
running and healthy. Used by .github/workflows/behavioral-tests.yml's
poll-until-healthy loop.
"""
import json
import sys

path = sys.argv[1]
lines = [json.loads(l) for l in open(path, encoding="utf-8") if l.strip()]
unhealthy = sum(
    1
    for c in lines
    if c.get("State") != "running" or c.get("Health") not in ("healthy", "")
)
print(unhealthy)
