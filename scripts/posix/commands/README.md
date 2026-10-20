# Plugin commands

A script dropped here as `<name>.sh` becomes `workstation <name> [args...]`
automatically - `scripts/posix/workstation.sh` execs it directly for any
command name that doesn't match one of its own hardcoded branches, with no
edit to that dispatcher (or `setup.ps1`'s, which routes into WSL for
anything it doesn't recognize either - see both files' own comments next to
their `default`/fallback case for the full rationale).

Added 2026-10-20 because every one of the ~35 built-in commands used to
require editing **two** separate dispatcher files by hand
(`scripts/posix/workstation.sh` and `setup.ps1`) and keeping them in sync -
a real drift already happened once (`project adopt` was missing from one of
the two help texts). A script here needs no dispatcher edit at all.

## Writing one

- `#!/usr/bin/env bash`, `set -euo pipefail`, same as every other script in
  this repo.
- Receives the command's own arguments only (`workstation scratch foo` ->
  your script sees `foo` as `$1`) - the command name itself is already
  consumed by the dispatcher.
- `$ROOT` is NOT set for you automatically - compute it yourself the same
  way every other script here does:
  `ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"` (three
  levels up: `commands/` -> `posix/` -> `scripts/` -> repo root).
- Exit non-zero on failure, same convention as every other command.
- Add it to `scripts/posix/workstation.sh`'s own help text under whichever
  section fits best (the dispatcher logic needs no change, but the command
  should still be discoverable from `workstation help`) - and to
  `setup.ps1`'s help text too if it's something a Windows user would
  reasonably reach for.

## What NOT to put here

A command that's genuinely Windows-native (no sensible WSL/Linux
equivalent) still needs its own dispatcher branch in `setup.ps1` - this
mechanism only covers POSIX scripts, routed into WSL on Windows the same
way `editor`/`dashboard`/`backup`/etc already are.
