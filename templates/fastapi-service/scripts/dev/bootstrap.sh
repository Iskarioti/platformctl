#!/usr/bin/env bash
set -euo pipefail
cd /workspace
uv sync --all-groups
uv run pre-commit install 2>/dev/null || true
