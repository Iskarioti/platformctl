#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

NO_AUTOSYNC=0
for arg in "$@"; do
  [[ "$arg" == "--no-autosync" ]] && NO_AUTOSYNC=1
done

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [[ -x /opt/homebrew/bin/brew ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -x /usr/local/bin/brew ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

brew update
brew install \
  git gh jq fzf zoxide ripgrep fd bat eza tmux direnv shellcheck powershell \
  docker docker-compose colima
brew install --cask \
  visual-studio-code \
  font-jetbrains-mono \
  font-jetbrains-mono-nerd-font
brew install jandedobbeleer/oh-my-posh/oh-my-posh

if ! colima status >/dev/null 2>&1; then
  colima start
fi

"$ROOT/scripts/posix/apply.sh"
"$ROOT/scripts/posix/configure-vscode.sh"
"$ROOT/scripts/posix/install-git-hooks.sh"
"$ROOT/scripts/posix/install-workstation-command.sh"

if [[ "$NO_AUTOSYNC" -eq 0 ]]; then
  "$ROOT/scripts/posix/install-autosync.sh"
fi

"$ROOT/setup" doctor
echo "macOS workstation bootstrap completed."
