# Claude Code Instructions

Read `AGENTS.md` first; it is authoritative.

Use this repository as source of truth. Prefer small, testable changes. Never edit a
live profile instead of its source file in this repository. Use `workstation validate`
before commit and `workstation apply` only after validation.

Do not use rsync. Do not bypass enterprise security controls. Do not add secrets.

When modifying platform automation, test dry-run/validation paths for Windows, Linux
and macOS where applicable.
