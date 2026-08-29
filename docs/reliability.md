# Reliability: testing, CI, and disaster recovery

This repo has repeatedly had bugs that pure schema/JSON validation could never catch:
a scheduled task that failed every single run since it was created, a Docker Compose
merge bug that silently corrupted `services up core`'s redis config, non-executable
shell scripts that would have broken `./bootstrap` on a fresh clone. This document
covers what actually closes that gap.

## Automated tests

`platformctl/tests/` is a real pytest suite for the control-plane (`platformctl serve`)
code: auth (password hashing, TOTP, session signing/expiry/revocation, login backoff),
the status pollers (with subprocess calls mocked - `platformctl/tests/test_status.py`),
the notification transition logic, and full HTTP integration tests against a real
FastAPI `TestClient` (enrollment, login, panels, the command runner, settings, audit
log, session revocation).

```bash
pip install -e "./platformctl[test]"
pytest platformctl/tests
```

`scripts/ci/control_plane_smoke.py` is a separate, reusable end-to-end smoke test
driven over real HTTP against an already-running `platformctl serve` instance - not
just for CI, run it by hand any time:

```bash
PLATFORMCTL_CONTROL_PLANE_DIR=/tmp/some-throwaway-dir platformctl serve --port 8765 &
python3 scripts/ci/control_plane_smoke.py --port 8765
```

## CI (`.github/workflows/behavioral-tests.yml`)

Scoped to `ubuntu-latest`: it's the only GitHub-hosted runner that can genuinely
exercise the Linux-native code path (Docker, `platformctl serve`) without WSL2/nested
virtualization, which GitHub-hosted Windows runners don't support. Windows-specific
behavior (Scheduled Tasks, WSL interop for background-job status) is not covered by
CI - it's covered by the manual verification pattern in `docs/control-plane.md`.

Four jobs:
- `python-tests` - the pytest suite above.
- `dev-services-core-smoke` - actually brings up `services up core` (postgres+redis)
  and asserts both containers reach `healthy`. This is a direct regression test for
  the project-directory Compose bug: it uses two services that each declare their own
  `./config/...` mount, which is exactly the shape that silently broke before the fix.
- `observability-compose-merge` - validates the 7-service observability profile's
  Compose config merges cleanly (`docker compose config`, no image pulls - kept fast
  and independent of Docker Hub/GHCR rate limits).
- `control-plane-e2e` - runs `control_plane_smoke.py` against a live `platformctl serve`.

## Disaster recovery (`workstation backup` / `workstation restore`)

Everything git doesn't cover: control-plane credentials (`~/.config/workstation/`),
dev-service secrets, labs state, and the named Docker volumes behind
postgres/redis/grafana/etc. Encrypted with `openssl enc -aes-256-cbc -pbkdf2`
(already a required tool in this repo - no new dependency) using a passphrase you
provide interactively; nothing plaintext ever touches disk for longer than the few
seconds it takes to tar and encrypt.

```bash
workstation backup                          # writes ~/workstation-backups/workstation-backup-<ts>.tar.gz.enc
workstation backup /path/to/output.tar.gz.enc
workstation restore /path/to/backup.tar.gz.enc
```

Restore is deliberately cautious:
- Decrypts to a staging area and shows exactly what it found before touching anything
  live; asks for confirmation unless `--yes`.
- An existing `~/.config/workstation` (or labs state dir) is **moved aside** with a
  timestamp, never overwritten in place.
- An existing Docker volume with the same name is **skipped**, not overwritten, unless
  you pass `--force-volumes`.
- A wrong passphrase fails cleanly with a clear error, not a corrupted partial restore.

Store the backup file (and remember the passphrase - it is not recoverable) somewhere
other than this machine. `WORKSTATION_BACKUP_PASSPHRASE` is accepted for
scripting/automation only; prefer the interactive prompt for real use so the
passphrase never sits in shell history.

## Changelog drafting (`workstation changelog`)

Prints a draft `CHANGELOG.md` section and a suggested semver bump from Conventional
Commits (`feat:`/`fix:`/`type!:`) since the last `VERSION` change - preview only, never
writes anything. This repo's history predates any enforcement of the convention, so
this is a helper to review and paste from, not a CI gate: retrofitting strict
enforcement onto existing autosync-generated commits would just break the workflow for
no benefit. Commits that don't follow `type: description` land under an "Other" bucket
verbatim.
