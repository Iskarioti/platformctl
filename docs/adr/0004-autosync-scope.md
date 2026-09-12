# 0004: Autosync manages only this repository, never application repos

**Status:** accepted

## Context

This workstation's own configuration lives in this git repository and is
kept continuously synchronized across machines via a background autosync
job (`docs/autosync.md`) that commits and pushes dirty changes on a timer.
Application code the user works on lives in entirely separate repositories
under `~/src/*`.

## Decision

Autosync manages `platformctl` itself only. It never adds automatic
commit/push behavior to any application repository - this is `AGENTS.md`
rule #12/#13.

## Consequences

- A change to workstation configuration is backed up within minutes with no
  manual step, matching the "fully automated" goal for the workstation
  layer itself.
- Application repos keep normal, deliberate git hygiene (feature branches,
  PR review, no surprise auto-commits) - autosync's convenience never
  leaks into a place where an unreviewed auto-commit would be a real
  problem.
- Autosync still fires every 5 minutes regardless of in-progress work on
  this repo, which is why `workstation autosync pause [minutes]` exists -
  pause before any multi-step edit touching several already-tracked files,
  resume once committed. A forgotten pause self-expires rather than
  disabling autosync indefinitely.
