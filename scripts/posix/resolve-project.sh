#!/usr/bin/env bash
# Source this - do not execute directly. Defines resolve_project_target().
#
# Governed projects don't live at $PWD - they live under a handful of known
# roots (policy/development.json's projectRoots: ~/src/company, ~/src/labs,
# etc), the same roots the "project"/"workspace" shell functions in
# architect.bashrc/zshrc search. "project open wiocchub-api" should find
# ~/src/company/wiocchub-api by name, not require the full path.
#
# Real bug this fixes: every "project *" subcommand used to do
# TARGET="$(cd "$TARGET" && pwd)" (or realpath, with a silent fallback) with
# no check that it actually succeeded. A bad argument's failed "cd" makes a
# command substitution return EMPTY, and "${1:-$PWD}" then treats that empty
# string as "unset" and silently defaults to $PWD - so "project open
# wiocchub-api" run from $HOME silently checked $HOME itself instead, and
# reported 11 unrelated FAILures (including flagging Dockerfile.template
# files under ~/.vscode-server/extensions/ as this "project"'s). Every
# consumer of this function must treat its failure as fatal (`|| exit N`),
# never fall through to a default.
#
# Usage: TARGET="$(resolve_project_target "$ROOT" "$1")" || exit 2

resolve_project_target() {
  local root="$1" arg="${2:-$PWD}" policy="$1/policy/development.json"

  if [[ -d "$arg" ]]; then
    (cd "$arg" && pwd)
    return 0
  fi

  local configured expanded match
  while IFS= read -r configured; do
    expanded="${configured/#\~/$HOME}"
    [[ -d "$expanded" ]] || continue
    match="$(find "$expanded" -mindepth 1 -maxdepth 3 -type d -name "$arg" -print -quit 2>/dev/null)"
    if [[ -n "$match" ]]; then
      (cd "$match" && pwd)
      return 0
    fi
  done < <(jq -r '.projectRoots[]' "$policy" 2>/dev/null)

  echo "Could not find project '$arg' as a path, or by name under any configured project root:" >&2
  jq -r '.projectRoots[] | "  " + .' "$policy" >&2
  return 1
}
