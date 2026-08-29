#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CMD="${1:-help}"
shift || true

case "$CMD" in
  validate)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoLogo -NoProfile -File "$ROOT/scripts/ci/validate.ps1" "$@"
    fi
    python3 -m json.tool "$ROOT/workstation.json" >/dev/null
    python3 -m json.tool "$ROOT/policy/development.json" >/dev/null
    python3 -m json.tool "$ROOT/windows-terminal/settings.json" >/dev/null
    echo "PASS basic POSIX validation"
    ;;
  doctor)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoLogo -NoProfile -File "$ROOT/scripts/common/doctor.ps1" "$@"
    fi
    for x in git gh code oh-my-posh zoxide fzf jq; do
      command -v "$x" >/dev/null 2>&1 && echo "PASS $x" || echo "MISS $x"
    done
    ;;
  enforce) exec "$ROOT/scripts/posix/enforce.sh" "$@" ;;
  project) exec "$ROOT/scripts/posix/project.sh" "$@" ;;
  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;
  sync) exec "$ROOT/scripts/common/autosync.sh" --once ;;
  publish)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoLogo -NoProfile -File "$ROOT/scripts/github/publish.ps1" "$@"
    fi
    exec "$ROOT/scripts/github/publish.sh" "$@"
    ;;
  autosync)
    action="${1:-status}"
    case "$action" in
      enable) exec "$ROOT/scripts/posix/install-autosync.sh" ;;
      disable) exec "$ROOT/scripts/posix/uninstall-autosync.sh" ;;
      once) exec "$ROOT/scripts/common/autosync.sh" --once ;;
      *) echo "autosync: enable | disable | once" ;;
    esac
    ;;
  update)
    git -C "$ROOT" pull --rebase --autostash
    "$ROOT/setup" validate
    "$ROOT/setup" apply
    "$ROOT/setup" doctor
    ;;
  dry-run)
    echo "DRY RUN: $(uname -s)"
    "$ROOT/scripts/posix/workstation.sh" validate
    ;;
  *)
    cat <<'EOF_HELP'
workstation commands:
  bootstrap
  apply
  validate
  doctor
  enforce [--repair]
  project init <template> <name> [--area company|platform|automation|labs|tooling]
  project check [path]
  project doctor [path]
  project open [path]
  project templates
  services init
  services list
  services up [service|profile ...]
  services stop <service ...>
  services down
  services restart <service ...>
  services logs <service>
  services status
  services doctor
  services urls
  services pull [service|profile ...]
  services project-up [path]
  services reset <service> [--yes]
  sync
  autosync enable|disable|once
  publish [owner/repo]
  update
  dry-run
EOF_HELP
    ;;
esac
