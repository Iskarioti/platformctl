# Architecture Decision Records

A dated, durable log of the real architectural calls behind this repo -
the Systems Engineer role review's highest-leverage, lowest-effort finding:
these decisions already existed, just scattered across prose and memory
rather than recorded anywhere durable.

Format: Status (`accepted` | `superseded by NNNN`), Context, Decision,
Consequences. Never delete or rewrite an accepted ADR - if a decision
changes, write a new one and mark the old one superseded.

| # | Title | Status |
|---|---|---|
| [0001](0001-wsl-nat-not-mirrored.md) | WSL networking stays NAT, not mirrored | accepted |
| [0002](0002-docker-in-wsl-not-desktop.md) | Docker runs inside WSL, never Docker Desktop | accepted |
| [0003](0003-dev-service-config-independence.md) | Dev-services never reference another service's variable names directly | accepted |
| [0004](0004-autosync-scope.md) | Autosync manages only this repository, never application repos | accepted |
| [0005](0005-single-machine-assumption.md) | This workstation is single-machine by design, with backup/restore as the accepted mitigation | accepted |
