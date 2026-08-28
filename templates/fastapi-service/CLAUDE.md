# Claude Code Project Instructions

Use this Dev Container as the execution boundary.

- Do not access paths outside `/workspace` unless explicitly authorized.
- Do not inspect `.env`, SSH keys, cloud credentials, tokens, or production dumps.
- Use `task` commands as the canonical developer interface.
- Run tests and static checks after changes.
- Do not push, deploy, or perform destructive infrastructure actions without explicit approval.
- Prefer generating a reviewable diff/PR-ready change over direct operational changes.
