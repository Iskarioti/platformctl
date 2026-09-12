# Dependency Updates

Every project template ships a `.github/dependabot.yml` (GitHub's native
dependency-update bot - no separate service to run or maintain, unlike
Renovate). Three ecosystems, per template, whichever actually apply:

| Ecosystem | Directory | Applies to |
|---|---|---|
| `github-actions` | `/` | every template (keeps CI's own actions patched) |
| `pip` | `/` | every Python template |
| `npm` | `/` | `react-app` |
| `docker` | `/.devcontainer` | every template with its own `.devcontainer/Dockerfile` |
| `terraform` | `/` | `infra`, `terraform` |

All weekly, all grouped into one PR per ecosystem (`groups:` with a catch-all
`patterns: ["*"]`) rather than one PR per package - a solo/small-team repo
reviewing one Python-deps PR a week is sustainable; reviewing fifteen
single-package PRs a week is not, and an ungrouped Dependabot config
degrades into "close without reading" within a month.

`github-actions` is deliberately left ungrouped-by-name but still uses the
same catch-all group - the point isn't selectivity, it's PR count.

## Review/merge workflow

1. Read the PR's own changelog links (Dependabot includes them) - a
   security-fix-only or genuinely breaking release changes how carefully to
   read.
2. This repo's own SHA-pinning convention
   (`uses: actions/checkout@<sha> # v4`, see `docs/adr/` and
   `templates/*/.github/workflows/*.yml`) means a `github-actions` bump
   updates the pinned SHA, not just a floating tag - the PR diff shows both
   the new SHA and the version comment, so a bump is still auditable at a
   glance even though it's pin-to-pin, not tag-to-tag.
3. Let the template's own CI run (`ci.yml`/`policy.yml`/`security.yml`) -
   merge on green, same bar as any other PR. Nothing here bypasses required
   checks.
4. A major-version bump that fails CI is exactly the case grouping is meant
   to isolate to its own PR (a group only auto-combines a compatible-range
   bump; Dependabot still opens major bumps separately by default) - fix or
   close it independently of the routine weekly PRs.

## Rotation vs. updates

Dependency updates patch code; they don't rotate secrets. For that, see
`docs/secrets-rotation.md`.
