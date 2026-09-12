# 0003: Dev-services never reference another service's variable names directly

**Status:** accepted

## Context

Docker Compose merges every resolved service's own `compose.yaml` and env
files into one flat namespace when `workstation services` builds its
combined invocation - meaning a dependent service's `compose.yaml` could
technically reference `${POSTGRES_PASSWORD}` directly, since the merge
makes that variable available. The `langfuse` dev-service was initially
built exactly this way: reading `${POSTGRES_PASSWORD}`, `${CLICKHOUSE_USER}`,
`${REDIS_PASSWORD}`, etc. straight out of its dependencies' own env files.

This worked, but silently coupled langfuse's config to each dependency's
internal naming - if postgres ever renamed or replaced `POSTGRES_PASSWORD`,
langfuse would break with no clear signal why.

## Decision

Every dev-service's own `compose.yaml`/`versions.env`/`defaults.env`/
`.env.example` must be independent of every other service's - never
reference another service's variable name directly, even when depending on
it for real infrastructure (`dependsOn` for startup ordering and shared
network reachability is fine). When a value can only come from a
dependency, declare it in `service.json`'s `consumes` map instead:

```json
"consumes": { "LANGFUSE_DB_PASSWORD": "postgres:POSTGRES_PASSWORD" }
```

`scripts/posix/services.sh`'s `generate_consumed_env()` resolves each entry
into a generated env file, so a service's `compose.yaml` only ever needs to
know its own variable names. This is `AGENTS.md` rule #15.

## Consequences

- A dependency can rename or replace its own internal variables without
  silently breaking every service that consumes it - the `consumes` map is
  the one place that needs updating.
- Retrofitted into `pgbouncer`, `redisinsight`, and `opensearch-dashboards`
  when this rule was introduced, since all three were already reading a
  dependency's variables directly.
- Every new dev-service (MLflow, per ADR-adjacent work) follows this from
  the start rather than being retrofitted later.
