# 0005: This workstation is single-machine by design, with backup/restore as the accepted mitigation

**Status:** accepted

## Context

The Systems Engineer & Architect role review flagged this directly: the
entire "Systems & Platform Architect workstation" concept currently lives
on one Windows+WSL machine, with no written acknowledgment that this is a
real single point of failure, and no rehearsed recovery path if that
machine were lost entirely rather than just its configuration.

## Decision

Accept the single-machine design as a deliberate tradeoff, not an
oversight - the workstation is built around one operator's daily-driver
machine, not a distributed or multi-node setup, and adding multi-machine
redundancy is out of scope for what this repo is trying to be.

The accepted mitigation is git-as-source-of-truth (every configuration
change is committed and pushed via autosync within minutes, see
ADR 0004) plus `workstation backup`/`restore` for the state that isn't
config - dev-service volumes and control-plane secrets.

## Consequences

- Losing this one machine means: re-clone the repo, re-run `bootstrap`, and
  restore from the most recent encrypted backup - a real, working path, but
  one that had never actually been rehearsed end-to-end before this
  decision was written down (see the disaster-recovery drill this ADR
  prompted).
- A second machine running this repo is assumed to converge to the same
  state via git alone - nothing today verifies that assumption holds in
  practice (a real gap, tracked separately from this ADR).
- If this workstation's scope ever genuinely grows into a multi-machine or
  multi-operator setup, that's a new ADR, not a quiet drift away from this
  one.
