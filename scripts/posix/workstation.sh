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
    echo
    echo "Cross-domain status (the single view a fully-fledged workstation needs -"
    echo "security/capacity/labs/templates, not just tool presence):"

    if [[ -f "$ROOT/.state/security/last-scan.json" ]]; then
      python3 - "$ROOT/.state/security/last-scan.json" <<'PY'
import json, sys, datetime
scan = json.load(open(sys.argv[1]))
scanned_at = datetime.datetime.fromisoformat(scan["scannedAtUtc"].replace("Z", "+00:00"))
age_days = (datetime.datetime.now(datetime.timezone.utc) - scanned_at).days
state = "PASS" if age_days <= 14 else "WARN"
print(f"{state}  security scan      {age_days}d ago against '{scan['target']}', "
      f"{scan['findingsCount']} tool(s) reported findings")
PY
    else
      echo "WARN  security scan      never run - workstation security scan ."
    fi

    disk_free_pct="$(df -k "$ROOT" 2>/dev/null | awk 'NR==2 {gsub("%","",$5); print 100-$5}')"
    if [[ -n "$disk_free_pct" ]]; then
      disk_state="PASS"; [[ "$disk_free_pct" -lt 10 ]] && disk_state="WARN"
      echo "$disk_state  disk               ${disk_free_pct}% free"
    fi
    if command -v free >/dev/null 2>&1; then
      mem_free_mb="$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')"
      if [[ -n "$mem_free_mb" ]]; then
        mem_state="PASS"; [[ "$mem_free_mb" -lt 512 ]] && mem_state="WARN"
        echo "$mem_state  memory             ${mem_free_mb} MB available"
      fi
    fi

    if command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
      running_count="$(docker ps --filter "name=^dev-" --format '{{.Names}}' | wc -l | tr -d ' ')"
      if [[ "$running_count" -gt 0 ]]; then
        if "$ROOT/scripts/posix/drift-check.sh" >/dev/null 2>&1; then
          echo "PASS  drift              $running_count running dev-service(s), none drifted from development/catalog.json"
        else
          echo "WARN  drift              running dev-service(s) don't match development/catalog.json - workstation drift-check"
        fi
      fi
    fi

    if command -v k3d >/dev/null 2>&1; then
      if k3d cluster list --no-headers 2>/dev/null | grep -q .; then
        echo "PASS  labs               k3d cluster(s) present - workstation lab status <name>"
      else
        echo "INFO  labs               no k3d clusters (workstation lab list)"
      fi
    fi

    if [[ -f "$ROOT/templates/catalog.json" && -f "$ROOT/policy/development.json" ]]; then
      python3 - "$ROOT" <<'PY'
import json, sys
from pathlib import Path

root = Path(sys.argv[1])
catalog = json.loads((root / "templates/catalog.json").read_text())["templates"]
policy = json.loads((root / "policy/development.json").read_text())

total = 0
outdated = 0
for raw_root in policy.get("projectRoots", []):
    proj_root = Path(raw_root.replace("~", str(Path.home()), 1))
    if not proj_root.is_dir():
        continue
    for child in proj_root.iterdir():
        meta_path = child / ".platformctl" / "project.json"
        if not meta_path.exists():
            continue
        total += 1
        meta = json.loads(meta_path.read_text())
        entry = catalog.get(meta.get("template"))
        if entry and meta.get("templateVersion") != entry.get("version"):
            outdated += 1

if total > 0:
    state = "WARN" if outdated > 0 else "PASS"
    print(f"{state}  templates          {outdated}/{total} project(s) on an outdated template version")
PY
    fi
    ;;
  enforce) exec "$ROOT/scripts/posix/enforce.sh" "$@" ;;
  project) exec "$ROOT/scripts/posix/project.sh" "$@" ;;
  services) exec "$ROOT/scripts/posix/services.sh" "$@" ;;
  security) exec "$ROOT/scripts/posix/security.sh" "$@" ;;
  research) exec "$ROOT/scripts/posix/research.sh" "$@" ;;
  catalog) exec "$ROOT/scripts/posix/catalog.sh" "$@" ;;
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
  dr-drill) exec "$ROOT/scripts/posix/dr-drill.sh" "$@" ;;
  drift-check) exec "$ROOT/scripts/posix/drift-check.sh" "$@" ;;
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
  catalog stats                        which templates/services actually get used
  catalog costs                        illustrative cloud-cost sizing for what's running now

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
  dr-drill                              rehearse backup+restore into a throwaway dir - proves it actually works
  drift-check                           compare running dev-services against development/catalog.json
  changelog [since-commit]
  publish [owner/repo]
  ssh-import                           copy Windows SSH keys into WSL (WSL only)
  update                               pull/rebase, validate, apply, doctor
  dry-run                              CI-safe platform simulation
EOF_HELP
    ;;
esac
