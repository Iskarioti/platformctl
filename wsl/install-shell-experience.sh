#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export PATH="$HOME/.local/bin:$PATH"

sudo apt-get update
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y \
  bash-completion fzf zoxide eza bat fd-find ripgrep direnv tmux jq tree btop \
  make gawk git curl unzip coreutils ca-certificates

mkdir -p "$HOME/.local/bin" "$HOME/.config/oh-my-posh" "$HOME/.local/share"

ln -sf "$(command -v batcat)" "$HOME/.local/bin/bat"
ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"

if ! command -v oh-my-posh >/dev/null 2>&1; then
  curl -s https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
fi

# Current Oh My Posh rprompt support in Bash uses ble.sh.
if [[ ! -f "$HOME/.local/share/blesh/ble.sh" ]]; then
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  git clone --recursive --depth 1 https://github.com/akinomyoga/ble.sh.git "$tmp/ble.sh"
  make -C "$tmp/ble.sh" install PREFIX="$HOME/.local"
fi

# Migrate away from the Starship installation previously owned by this repo.
if [[ -f "$HOME/.config/starship.toml" ]]; then
  mv "$HOME/.config/starship.toml" \
    "$HOME/.config/starship.toml.migrated.$(date +%Y%m%d-%H%M%S).bak"
fi

if [[ -x "$HOME/.local/bin/starship" ]]; then
  rm -f "$HOME/.local/bin/starship"
fi

install -m 600 \
  "$ROOT_DIR/shell/oh-my-posh/tokyonight-architect.omp.json" \
  "$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"

install -m 600 \
  "$ROOT_DIR/shell/bash/architect.bashrc" \
  "$HOME/.config/architect.bashrc"

START='# >>> systems-platform-architect shell >>>'
if ! grep -Fq "$START" "$HOME/.bashrc"; then
  cat >> "$HOME/.bashrc" <<'BASHRC'

# >>> systems-platform-architect shell >>>
[[ -f "$HOME/.config/architect.bashrc" ]] && source "$HOME/.config/architect.bashrc"
# <<< systems-platform-architect shell <<<
BASHRC
fi

cat > "$HOME/.tmux.conf" <<'TMUX'
set -g mouse on
set -g history-limit 100000
set -g base-index 1
setw -g pane-base-index 1
set -g renumber-windows on
set -g escape-time 10
setw -g mode-keys vi
bind | split-window -h
bind - split-window -v
bind r source-file ~/.tmux.conf \; display-message "tmux reloaded"
set -g status-interval 5
set -g status-left '#S '
set -g status-right '%Y-%m-%d %H:%M'
TMUX

printf '\nShell experience installed.\n'
printf '  Oh My Posh: %s\n' "$(command -v oh-my-posh)"
printf '  Theme:      %s\n' "$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"
printf '  ble.sh:     %s\n' "$HOME/.local/share/blesh/ble.sh"
printf '\nRun: exec bash\n'
