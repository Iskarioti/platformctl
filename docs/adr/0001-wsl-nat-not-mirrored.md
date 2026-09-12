# 0001: WSL networking stays NAT, not mirrored

**Status:** accepted

## Context

WSL2 supports two networking modes: the legacy NAT mode, and a newer
"mirrored" mode that gives WSL a network interface that mirrors the host's,
simplifying localhost/VPN interaction. Mirrored mode is generally the more
modern, less surprising choice for a machine with no other constraints.

## Decision

This workstation stays on NAT (`networkingMode` left at its default in
`.wslconfig`), not mirrored - mirrored mode was tested and found to break
WSL networking entirely on this machine, due to a conflict with the
Global Secure Access (GSA) client used on this corporate network.

## Consequences

- WSL networking works reliably, at the cost of not getting mirrored mode's
  simpler localhost/VPN interaction model.
- The repo's own `.wslconfig` and the actually-deployed `.wslconfig` can
  drift apart silently - always diff before trusting the repo file (see
  `docs/architecture.md`).
- **Never suggest switching back to mirrored mode** without first
  confirming the GSA conflict no longer applies on this network.
