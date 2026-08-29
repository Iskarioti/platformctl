#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
git -C "$ROOT" config core.hooksPath .githooks
git -C "$ROOT" config pull.rebase true
git -C "$ROOT" config fetch.prune true
chmod +x "$ROOT/.githooks/"*
