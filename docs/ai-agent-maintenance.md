# Maintaining the Workstation with AI Agents

Supported agent styles include Claude Code, Codex, Kimi and other repository-aware
coding agents.

## Start every agent task with

```text
Read AGENTS.md and docs/architecture.md.
Run workstation validate before editing.
```

## Recommended task prompt

```text
Improve <feature> in this workstation repository.
Preserve cross-platform behavior, cp/Copy-Item deployment, enterprise security
controls, JetBrains font standards, GitHub autosync, and idempotency.
Update tests/docs/changelog and run workstation validate.
```

## Branches

For small personal changes, editing the current branch is supported and autosync
will push it.

For substantial changes:

```bash
git switch -c feat/<topic>
```

The post-commit hook pushes that branch automatically. Merge after review.

## Forbidden agent behavior

- placing credentials in source;
- weakening Windows security policy;
- replacing cp with rsync;
- editing generated/deployed copies instead of canonical source;
- force pushing;
- silently removing platform support.
