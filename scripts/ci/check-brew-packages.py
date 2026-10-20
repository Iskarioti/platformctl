#!/usr/bin/env python3
"""Confirms every Homebrew formula/cask this repo's macOS scripts reference
still resolves in Homebrew's current catalog, via `brew info` (read-only,
installs nothing). Catches a real class of bug - a renamed or discontinued
cask/formula - that `setup.ps1 dry-run`'s syntax-only check can't, on a repo
that (as of this writing) has never had a real Mac to catch it on either.
Intended to run only on a macos-latest CI runner, where `brew` is preinstalled.

Pass --dry-run to print what WOULD be checked without calling `brew info` at
all - used to verify the extraction logic itself is parsing package names
correctly, from a machine (or CI job) with no Homebrew available.
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TARGET_FILES = [
    "platform/macos/bootstrap.sh",
    "platform/macos/install-security-tools.sh",
    "platform/macos/install-research-tools.sh",
]


def extract_calls(text):
    """Yields (is_cask, [names]) for each `brew install [--cask] ...`
    invocation in text, joining backslash-continued lines first so a
    multi-line `brew install \\\n  a b c` block is read as one list."""
    joined = re.sub(r"\\\r?\n\s*", " ", text)
    calls = []
    for match in re.finditer(r"brew install\s+(--cask\s+)?([^\n]+)", joined):
        is_cask = bool(match.group(1))
        # Stop at the first shell statement separator so a later, unrelated
        # command on the same joined line is never swallowed into this list.
        rest = re.split(r"[;&|]", match.group(2))[0]
        names = [w for w in rest.split() if w and not w.startswith("-")]
        if names:
            calls.append((is_cask, names))
    return calls


def main():
    dry_run = "--dry-run" in sys.argv
    failures = []
    checked = 0

    for rel in TARGET_FILES:
        path = ROOT / rel
        if not path.exists():
            continue
        for is_cask, names in extract_calls(path.read_text()):
            kind = "cask" if is_cask else "formula"
            for name in names:
                checked += 1
                if dry_run:
                    print(f"WOULD CHECK {kind:8} {name}  ({rel})")
                    continue
                result = subprocess.run(
                    ["brew", "info", "--cask" if is_cask else "--formula", name],
                    capture_output=True, text=True,
                )
                if result.returncode == 0:
                    print(f"OK       {kind:8} {name}  ({rel})")
                else:
                    print(f"MISSING  {kind:8} {name}  ({rel})")
                    failures.append(f"{name} ({kind}, from {rel})")

    print()
    print(f"Checked {checked} brew package reference(s).")
    if dry_run:
        return
    if failures:
        print(f"FAILED: {len(failures)} package(s) no longer resolve in Homebrew's catalog:")
        for f in failures:
            print(f"  - {f}")
        sys.exit(1)
    print("All brew formula/cask references resolve.")


if __name__ == "__main__":
    main()
