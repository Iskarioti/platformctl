#!/usr/bin/env bash
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATE_DIR="$ROOT/.state"
mkdir -p "$STATE_DIR"
LOG="$STATE_DIR/upgrade-$(date +%Y-%m-%d).log"

log() {
  local line
  line="[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $1"
  echo "$line"
  echo "$line" >> "$LOG"
}

command -v jq >/dev/null 2>&1 || { echo "jq is required to read workstation.json." >&2; exit 2; }

ENABLED="$(jq -r '.autoUpdate.enabled // false' "$ROOT/workstation.json")"
if [[ "$ENABLED" != "true" ]]; then
  log "SKIP: autoUpdate.enabled is false (or unset) in workstation.json."
  exit 0
fi

SCOPE_ARG=()
UNATTENDED=0
for arg in "$@"; do
  case "$arg" in
    --unattended) UNATTENDED=1 ;;
    --scope=*) SCOPE_ARG+=("${arg#--scope=}") ;;
  esac
done

if [[ "${#SCOPE_ARG[@]}" -eq 0 ]]; then
  mapfile -t SCOPE_ARG < <(jq -r '.autoUpdate.scope[]? // empty' "$ROOT/workstation.json")
fi
if [[ "${#SCOPE_ARG[@]}" -eq 0 ]]; then
  SCOPE_ARG=(packages vscodeExtensions fonts)
fi

if [[ "$UNATTENDED" -eq 1 ]]; then
  WINDOW_START="$(jq -r '.autoUpdate.schedule.windowStart // empty' "$ROOT/workstation.json")"
  WINDOW_END="$(jq -r '.autoUpdate.schedule.windowEnd // empty' "$ROOT/workstation.json")"

  if [[ -n "$WINDOW_START" && -n "$WINDOW_END" ]]; then
    NOW_MIN=$((10#$(date +%H) * 60 + 10#$(date +%M)))
    START_MIN=$(( 10#${WINDOW_START%%:*} * 60 + 10#${WINDOW_START##*:} ))
    END_MIN=$(( 10#${WINDOW_END%%:*} * 60 + 10#${WINDOW_END##*:} ))

    if [[ "$START_MIN" -le "$END_MIN" ]]; then
      IN_WINDOW=$(( NOW_MIN >= START_MIN && NOW_MIN < END_MIN ? 1 : 0 ))
    else
      # Window wraps past midnight, e.g. 22:00-06:00.
      IN_WINDOW=$(( (NOW_MIN >= START_MIN || NOW_MIN < END_MIN) ? 1 : 0 ))
    fi

    if [[ "$IN_WINDOW" -eq 0 ]]; then
      log "SKIP: outside configured update window ($WINDOW_START-$WINDOW_END)."
      exit 0
    fi
  fi

  SKIP_IF_RUNNING="$(jq -r '.autoUpdate.skipIfContainersRunning // false' "$ROOT/workstation.json")"
  if [[ "$SKIP_IF_RUNNING" == "true" ]] && command -v docker >/dev/null 2>&1; then
    RUNNING="$(docker ps --format '{{.Names}}' 2>/dev/null || true)"
    if [[ -n "$RUNNING" ]]; then
      log "SKIP: containers currently running ($(echo "$RUNNING" | tr '\n' ' ')); not disturbing active work."
      exit 0
    fi
  fi
fi

log "Starting workstation upgrade. Scope: ${SCOPE_ARG[*]}"
FAILURES=0

run_step() {
  local label="$1"; shift
  log "RUN $label"
  if "$@" >>"$LOG" 2>&1; then
    log "DONE $label"
  else
    log "FAIL $label"
    FAILURES=$((FAILURES + 1))
  fi
}

for item in "${SCOPE_ARG[@]}"; do
  case "$item" in
    packages)
      case "$(uname -s)" in
        Linux)
          # These GUI apps are only conditionally installed (some need a
          # display - alacritty/librewolf/wireshark; solaar/wireguard don't,
          # but still aren't part of every machine's baseline) - check each is
          # actually installed before including it, rather than assume. An
          # `apt-get install --only-upgrade` on a package name that was never
          # installed (e.g. librewolf's extrepo-added repo was never enabled)
          # errors "Unable to locate package" and fails the whole step, so
          # this can't just list them unconditionally the way the guaranteed-
          # present baseline tools below are.
          if command -v apt-get >/dev/null 2>&1; then
            EXTRA_PKGS=()
            for pkg in alacritty librewolf wireshark wireguard solaar; do
              dpkg -s "$pkg" >/dev/null 2>&1 && EXTRA_PKGS+=("$pkg")
            done
            run_step "packages (apt update)" sudo apt-get update
            run_step "packages (apt upgrade curated list)" sudo apt-get install --only-upgrade -y \
              git curl unzip ca-certificates jq fzf zoxide ripgrep fd-find bat tmux direnv shellcheck python3 python3-venv fontconfig \
              "${EXTRA_PKGS[@]}"
          elif command -v dnf >/dev/null 2>&1; then
            EXTRA_PKGS=()
            for pkg in alacritty librewolf wireshark wireguard-tools solaar; do
              rpm -q "$pkg" >/dev/null 2>&1 && EXTRA_PKGS+=("$pkg")
            done
            run_step "packages (dnf upgrade curated list)" sudo dnf upgrade -y \
              git curl unzip ca-certificates jq fzf zoxide ripgrep fd-find bat tmux direnv ShellCheck python3 fontconfig \
              "${EXTRA_PKGS[@]}"
          elif command -v pacman >/dev/null 2>&1; then
            EXTRA_PKGS=()
            for pkg in alacritty librewolf wireshark-qt wireguard-tools solaar; do
              pacman -Qi "$pkg" >/dev/null 2>&1 && EXTRA_PKGS+=("$pkg")
            done
            run_step "packages (pacman upgrade curated list)" sudo pacman -Syu --needed --noconfirm \
              git curl unzip ca-certificates jq fzf zoxide ripgrep fd bat tmux direnv shellcheck python fontconfig \
              "${EXTRA_PKGS[@]}"
          else
            log "SKIP packages: unsupported Linux package manager."
          fi
          ;;
        Darwin)
          run_step "packages (brew update)" brew update
          run_step "packages (brew upgrade)" brew upgrade \
            git gh jq fzf zoxide ripgrep fd bat eza tmux direnv shellcheck powershell docker docker-compose colima oh-my-posh
          # `brew upgrade --cask <name>` errors on a cask that was never
          # installed - same reasoning as the Linux EXTRA_PKGS check above,
          # check presence first rather than assume every cask this repo can
          # install is actually present on every machine.
          EXTRA_CASKS=()
          for cask in visual-studio-code librewolf alacritty bingpaper logi-options+ wireshark-app wireguard microsoft-teams microsoft-outlook; do
            brew list --cask "$cask" >/dev/null 2>&1 && EXTRA_CASKS+=("$cask")
          done
          if [[ "${#EXTRA_CASKS[@]}" -gt 0 ]]; then
            run_step "packages (brew upgrade --cask)" brew upgrade --cask "${EXTRA_CASKS[@]}"
          fi
          ;;
        *)
          log "SKIP packages: unsupported platform $(uname -s)."
          ;;
      esac
      ;;
    vscodeExtensions)
      run_step "vscodeExtensions" "$ROOT/scripts/posix/configure-vscode.sh"
      ;;
    fonts)
      case "$(uname -s)" in
        Linux) run_step "fonts" "$ROOT/platform/linux/install-fonts.sh" ;;
        Darwin) run_step "fonts (brew upgrade --cask)" brew upgrade --cask font-jetbrains-mono font-jetbrains-mono-nerd-font ;;
        *) log "SKIP fonts: unsupported platform $(uname -s)." ;;
      esac
      ;;
    *)
      log "SKIP unknown scope item: $item"
      ;;
  esac
done

log "workstation upgrade completed. Failures: $FAILURES"
[[ "$FAILURES" -gt 0 ]] && exit 1
exit 0
