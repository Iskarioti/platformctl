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
    for x in git gh code oh-my-posh zoxide fzf jq devcontainer; do
      command -v "$x" >/dev/null 2>&1 && echo "PASS $x" || echo "MISS $x"
    done
    echo
    echo "Security/research toolchain (workstation security|research doctor for detail):"
    export PATH="$HOME/.local/bin:$PATH"
    for x in semgrep gitleaks trufflehog trivy grype syft cosign conftest checkov pdflatex biber latexmk pandoc quarto pixi; do
      command -v "$x" >/dev/null 2>&1 && echo "PASS $x" || echo "MISS $x (run: workstation security|research install)"
    done
    ;;
  enforce) exec "$ROOT/scripts/posix/enforce.sh" "$@" ;;
  project) exec "$ROOT/scripts/posix/project.sh" "$@" ;;
  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;
  security) exec "$ROOT/scripts/posix/security.sh" "$@" ;;
  research) exec "$ROOT/scripts/posix/research.sh" "$@" ;;
  models) exec "$ROOT/scripts/posix/models.sh" "$@" ;;
  lab) exec "$ROOT/scripts/posix/labs.sh" "$@" ;;
  editor) exec "$ROOT/scripts/posix/editor.sh" "$@" ;;
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
      pause)
        minutes="${2:-30}"
        mkdir -p "$ROOT/.state"
        target_epoch=$(( $(date -u +%s) + minutes * 60 ))
        if date -u -d @0 >/dev/null 2>&1; then
          expiry="$(date -u -d "@$target_epoch" +%Y-%m-%dT%H:%M:%SZ)"
        else
          expiry="$(date -u -r "$target_epoch" +%Y-%m-%dT%H:%M:%SZ)"
        fi
        echo "$expiry" > "$ROOT/.state/autosync.pause"
        echo "Autosync paused until $expiry (run 'workstation autosync resume' to lift early)."
        ;;
      resume)
        rm -f "$ROOT/.state/autosync.pause"
        echo "Autosync resumed."
        ;;
      *) echo "autosync: enable | disable | once | pause [minutes] | resume" ;;
    esac
    ;;
  upgrade) exec "$ROOT/scripts/posix/upgrade.sh" "$@" ;;
  ssh-import) exec "$ROOT/wsl/import-windows-ssh-keys.sh" "$@" ;;
  dashboard)
    action="${1:-}"
    case "$action" in
      enable)
        shift
        exec "$ROOT/scripts/posix/install-dashboard-service.sh" "$@"
        ;;
      disable)
        exec "$ROOT/scripts/posix/uninstall-dashboard-service.sh"
        ;;
      status)
        case "$(uname -s)" in
          Linux) exec systemctl --user status workstation-dashboard.service --no-pager -l ;;
          Darwin) exec launchctl list com.workstation.dashboard ;;
          *) echo "Use platform-native service status commands." ;;
        esac
        ;;
      *) exec platformctl serve "$@" ;;
    esac
    ;;
  backup) exec "$ROOT/scripts/posix/backup.sh" "$@" ;;
  restore) exec "$ROOT/scripts/posix/restore.sh" "$@" ;;
  changelog)
    if command -v pwsh >/dev/null 2>&1; then
      exec pwsh -NoLogo -NoProfile -File "$ROOT/scripts/common/changelog-preview.ps1" "$@"
    fi
    echo "changelog preview requires pwsh (PowerShell 7), which this repo already requires." >&2
    exit 2
    ;;
  autoupgrade)
    action="${1:-status}"
    case "$action" in
      enable) exec "$ROOT/scripts/posix/install-autoupgrade.sh" ;;
      disable) exec "$ROOT/scripts/posix/uninstall-autoupgrade.sh" ;;
      once) exec "$ROOT/scripts/posix/upgrade.sh" ;;
      *) echo "autoupgrade: enable | disable | once" ;;
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
workstation commands  (new here? see docs/getting-started.md)

Workstation health:
  bootstrap                          set up this machine (fonts, shell, editor,
                                      DevSecOps/research toolchains, Docker/WSL)
  apply                               redeploy managed configs from repo source
  validate                            validate workstation/policy JSON + safety invariants
  doctor                               check installed tools + background automation
  enforce [--repair]                  check/repair development-policy compliance

Start a project:
  project templates                   list approved project templates
  project init <template> <name> [--area company|platform|automation|labs|tooling]
  project adopt [path|name]           register an existing/cloned project
  project check|doctor|open [path|name]

Local infrastructure:
  services init|list|up|stop|down|restart|logs|status|doctor|urls|pull|project-up|reset
  services autostart enable|disable|status [service ...]   survive Docker/WSL restart + PC reboot
  models up|down|status|pull <model>|list|run <model>       shared local Ollama runtime
  lab list|info|toolchain|cluster|up|status|logs|test|stop|destroy|report   pre-production architecture labs

Quality & security:
  security scan [path]                semgrep/gitleaks/trufflehog/trivy/checkov
  security sbom [path] [out]          CycloneDX SBOM via syft
  security doctor                     verify security toolchain installed
  research doctor                     verify research (LaTeX/pandoc/quarto/pixi) toolchain

Editor & shell:
  editor install|apply|doctor|list|profile|sync|clean

Automation & maintenance:
  sync                                 validate -> apply -> commit -> push once
  autosync enable|disable|once|pause [minutes]|resume
  upgrade [--scope=packages|vscodeExtensions|fonts]
  autoupgrade enable|disable|once
  dashboard [--port N]                 run once (foreground)
  dashboard enable|disable|status      always-on background service (auto-restart, starts at login)
  backup [output-path]
  restore <backup-file> [--yes]
  changelog [since-commit]
  publish [owner/repo]
  ssh-import                           copy Windows SSH keys into WSL (WSL only)
  update                               pull/rebase, validate, apply, doctor
  dry-run                              CI-safe platform simulation
EOF_HELP
    ;;
esac
