#!/usr/bin/env bash
set -euo pipefail

# Low-ceremony experimentation space - the one real gap found in a
# cross-domain persona audit (2026-10-20): every platformctl project,
# however trivial, had to clear project-check.sh's full governed-project
# bar (devcontainer, 3 CI workflow files, lockfile, .env.example) with no
# "just let me try something" escape hatch. Lives at ~/scratch, deliberately
# OUTSIDE every policy/development.json projectRoots entry - not
# registered, not adopted, invisible to project-check/doctor/the
# dashboard's governed-projects panel by design. The first command shipped
# as a scripts/posix/commands/ plugin (see that directory's README) rather
# than a hardcoded dispatcher branch.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
SCRATCH_ROOT="$HOME/scratch"

usage() {
  cat <<'USAGE'
workstation scratch commands:
  <name>                  create ~/scratch/<name> and print next steps (default action)
  create <name>           same as above, explicit
  list                    show every scratch space and its age
  clean [--older-than Nd] remove scratch spaces older than N days (default: 30)
  promote <name> <template> <project-name> [--area ...]
                          graduate a scratch space into a real governed project -
                          scaffolds <template> via "project init", then copies your
                          scratch files in without overwriting the template's own
                          scaffolding. The original scratch space is left in place;
                          remove it yourself once you've verified the copy.
USAGE
}

ACTION="${1:-}"
case "$ACTION" in
  create|list|clean|promote|help|-h|--help) shift ;;
  *)
    # No recognized subcommand - treat the whole first arg as a name, i.e.
    # "workstation scratch my-idea" is the common case, not the more
    # explicit "workstation scratch create my-idea".
    ACTION="create"
    ;;
esac

case "$ACTION" in
  help|-h|--help) usage ;;

  create)
    NAME="${1:-}"
    [[ -n "$NAME" ]] || { echo "Usage: workstation scratch <name>" >&2; exit 2; }
    [[ "$NAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9._-]*$ ]] || {
      echo "Name contains unsupported characters: $NAME" >&2; exit 2;
    }

    DEST="$SCRATCH_ROOT/$NAME"
    if [[ -e "$DEST" ]]; then
      echo "Already exists: $DEST"
    else
      mkdir -p "$DEST"
      cat > "$DEST/README.md" <<EOF
# $NAME (scratch space)

Created $(date -u +%Y-%m-%dT%H:%M:%SZ). Not a governed platformctl project -
no devcontainer, no CI, no policy compliance required. Nothing here is
tracked by \`workstation doctor\`/the dashboard's governed-projects panel.

Became something real? Graduate it:

    workstation scratch promote $NAME <template> <project-name>
EOF
      cat > "$DEST/.gitignore" <<'GITIGNORE'
__pycache__/
*.pyc
.venv/
node_modules/
.DS_Store
GITIGNORE
      echo "Created: $DEST"
    fi
    echo ""
    echo "Next:"
    echo "  cd $DEST"
    echo "  code ."
    ;;

  list)
    if [[ ! -d "$SCRATCH_ROOT" ]]; then
      echo "No scratch spaces yet - run: workstation scratch <name>"
      exit 0
    fi
    echo "=== Scratch spaces (~/scratch) ==="
    found=0
    while IFS= read -r dir; do
      found=1
      name="$(basename "$dir")"
      mtime="$(stat -c %Y "$dir" 2>/dev/null || stat -f %m "$dir")"
      age_days=$(( ( $(date +%s) - mtime ) / 86400 ))
      printf '%-30s %s day(s) old\n' "$name" "$age_days"
    done < <(find "$SCRATCH_ROOT" -mindepth 1 -maxdepth 1 -type d | sort)
    [[ "$found" -eq 1 ]] || echo "(empty)"
    ;;

  clean)
    OLDER_THAN=30
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --older-than) OLDER_THAN="${2%d}"; shift 2 ;;
        *) echo "Unknown argument: $1" >&2; exit 2 ;;
      esac
    done
    if [[ ! -d "$SCRATCH_ROOT" ]]; then
      echo "No scratch spaces to clean."
      exit 0
    fi
    removed=0
    while IFS= read -r dir; do
      echo "Removing: $dir (older than ${OLDER_THAN}d)"
      rm -rf "$dir"
      removed=$((removed + 1))
    done < <(find "$SCRATCH_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime "+$OLDER_THAN")
    echo "Removed $removed scratch space(s)."
    ;;

  promote)
    NAME="${1:-}"; TEMPLATE="${2:-}"; PROJECT_NAME="${3:-}"
    if [[ -z "$NAME" || -z "$TEMPLATE" || -z "$PROJECT_NAME" ]]; then
      echo "Usage: workstation scratch promote <scratch-name> <template> <project-name> [--area ...]" >&2
      exit 2
    fi
    shift 3

    SRC="$SCRATCH_ROOT/$NAME"
    [[ -d "$SRC" ]] || { echo "No such scratch space: $SRC" >&2; exit 2; }

    "$ROOT/scripts/posix/project-init.sh" "$TEMPLATE" "$PROJECT_NAME" "$@"

    source "$ROOT/scripts/posix/resolve-project.sh"
    DEST="$(resolve_project_target "$ROOT" "$PROJECT_NAME")" || exit 2

    echo "Copying scratch files from $SRC into $DEST (not overwriting template scaffolding)..."
    cp -rn "$SRC"/. "$DEST"/ 2>/dev/null || true

    echo ""
    echo "Promoted: $SRC -> $DEST"
    echo "The original scratch space at $SRC was left in place - remove it yourself"
    echo "once you've verified the copy (workstation scratch clean only removes"
    echo "spaces older than 30 days by default)."
    ;;
esac
