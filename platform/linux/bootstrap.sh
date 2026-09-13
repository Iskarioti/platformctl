#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NO_AUTOSYNC=0
NO_AUTOUPGRADE=0
for arg in "$@"; do
  [[ "$arg" == "--no-autosync" ]] && NO_AUTOSYNC=1
  [[ "$arg" == "--no-autoupgrade" ]] && NO_AUTOUPGRADE=1
done

if command -v apt-get >/dev/null 2>&1; then
  sudo apt-get update
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git curl unzip ca-certificates jq fzf zoxide ripgrep fd-find bat tmux \
    direnv shellcheck python3 python3-venv fontconfig
  sudo DEBIAN_FRONTEND=noninteractive apt-get install -y alacritty || \
    echo "NOTE: alacritty not installed (GUI terminal - only useful with a display, e.g. WSLg)." >&2
elif command -v dnf >/dev/null 2>&1; then
  sudo dnf install -y \
    git curl unzip ca-certificates jq fzf zoxide ripgrep fd-find bat tmux \
    direnv ShellCheck python3 fontconfig
  sudo dnf install -y alacritty || \
    echo "NOTE: alacritty not installed (GUI terminal - only useful with a display, e.g. WSLg)." >&2
elif command -v pacman >/dev/null 2>&1; then
  sudo pacman -Sy --needed --noconfirm \
    git curl unzip ca-certificates jq fzf zoxide ripgrep fd bat tmux direnv \
    shellcheck python fontconfig
  sudo pacman -S --needed --noconfirm alacritty || \
    echo "NOTE: alacritty not installed (GUI terminal - only useful with a display, e.g. WSLg)." >&2
else
  echo "Unsupported Linux package manager." >&2
  exit 3
fi

"$ROOT/platform/linux/install-fonts.sh"
"$ROOT/platform/linux/install-oh-my-posh.sh"
"$ROOT/platform/linux/install-docker.sh"
"$ROOT/platform/linux/install-vscode.sh" || true
"$ROOT/platform/linux/install-gh.sh" || true
"$ROOT/platform/linux/install-librewolf.sh" || true
"$ROOT/platform/linux/install-solaar.sh" || true
"$ROOT/platform/linux/install-wireshark.sh" || true
"$ROOT/platform/linux/install-wireguard.sh" || true
# Microsoft Teams and Outlook have no supported Linux client (Teams' Linux app
# was discontinued in 2022; Outlook has never shipped one) - use the web apps
# (teams.microsoft.com / outlook.office.com) instead. Not installed here, and
# deliberately not faked via a Flatpak/Electron wrapper of the web app.
"$ROOT/platform/linux/install-security-tools.sh" || true
"$ROOT/platform/linux/install-research-tools.sh" || true
"$ROOT/scripts/posix/install-devcontainers-cli.sh" || true

"$ROOT/scripts/posix/apply.sh"
"$ROOT/scripts/posix/configure-vscode.sh" || true
"$ROOT/scripts/posix/install-git-hooks.sh"
"$ROOT/scripts/posix/install-workstation-command.sh"

if [[ "$NO_AUTOSYNC" -eq 0 ]]; then
  "$ROOT/scripts/posix/install-autosync.sh"
fi

if [[ "$NO_AUTOUPGRADE" -eq 0 ]]; then
  "$ROOT/scripts/posix/install-autoupgrade.sh"
fi

"$ROOT/setup" doctor
echo "Linux workstation bootstrap completed."

# Informational: report development-policy compliance without failing bootstrap
# over it (enforce.sh legitimately reports non-zero when policy is unmet).
"$ROOT/scripts/posix/enforce.sh" || true
