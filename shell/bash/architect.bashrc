# Systems & Platform Architect - managed Bash shell fragment.
# Source this from ~/.bashrc after normal distro defaults.

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="code --wait"
export VISUAL="$EDITOR"
export LESS="-R"
export PAGER="less"
export VIRTUAL_ENV_DISABLE_PROMPT=1

HISTCONTROL=ignoreboth:erasedups
HISTSIZE=100000
HISTFILESIZE=200000
shopt -s histappend cmdhist lithist

if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

if command -v fzf >/dev/null 2>&1; then
  if fzf --bash >/dev/null 2>&1; then
    eval "$(fzf --bash)"
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.bash ]] && source /usr/share/doc/fzf/examples/key-bindings.bash
    [[ -f /usr/share/bash-completion/completions/fzf ]] && source /usr/share/bash-completion/completions/fzf
  fi
fi

export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border --info=inline'
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook bash)"

alias ls='eza'
alias l='eza -lah --group-directories-first'
alias ll='eza -lah --group-directories-first --git'
alias lt='eza --tree --level=2 --group-directories-first'
alias lta='eza --tree --level=3 --all --group-directories-first'
alias cat='bat --paging=never'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cls='clear'

alias g='git'
alias gs='git status'
alias ga='git add'
alias gaa='git add --all'
alias gc='git commit'
alias gca='git commit --amend'
alias gp='git push'
alias gl='git pull --ff-only'
alias gf='git fetch --all --prune'
alias gd='git diff'
alias gds='git diff --staged'
alias gb='git branch'
alias gsw='git switch'
alias glog='git log --graph --decorate --oneline --all'

alias d='docker'
alias dc='docker compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'
alias dcu='docker compose up -d'
alias dcd='docker compose down'
alias dcl='docker compose logs -f'
alias ddf='docker system df'

alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgn='kubectl get nodes'
alias kga='kubectl get all'
alias kctx='kubectl config current-context'

alias tf='terraform'
alias tfi='terraform init'
alias tfp='terraform plan'
alias tfv='terraform validate'
alias tff='terraform fmt -recursive'

alias ports='ss -tulpn'
alias routes='ip route'
alias rules='ip rule'
alias mem='free -h'
alias disk='df -h'
alias top='btop'

ccompany() { cd "$HOME/src/company" || return; }
cplatform() { cd "$HOME/src/platform" || return; }
clabs() { cd "$HOME/src/labs" || return; }
ctooling() { cd "$HOME/src/tooling" || return; }
cautomation() { cd "$HOME/src/automation" || return; }
mkcd() { mkdir -p "$1" && cd "$1"; }

croot() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  cd "$root" || return
}

project() {
  local root="${1:-$HOME/src}"
  local dir
  dir="$(find "$root" -mindepth 1 -maxdepth 4 -type d -name .git -printf '%h\n' 2>/dev/null \
    | fzf --prompt='Project> ' --preview='eza -lah --git {}')"
  [[ -n "$dir" ]] && cd "$dir"
}

gbs() {
  local branch
  branch="$(git branch --all --format='%(refname:short)' | sort -u | fzf --prompt='Branch> ')"
  [[ -z "$branch" ]] && return 0
  if [[ "$branch" == origin/* ]]; then
    git switch --track "$branch" 2>/dev/null || git switch "${branch#origin/}"
  else
    git switch "$branch"
  fi
}

psg() { ps aux | rg -i "$1"; }
listen() { sudo ss -lptn "sport = :$1"; }
ops() { tmux new-session -A -s ops; }

# ble.sh enables a reliable Oh My Posh rprompt in Bash.
if [[ -f "$HOME/.local/share/blesh/ble.sh" ]]; then
  source "$HOME/.local/share/blesh/ble.sh" --attach=none
fi

if command -v oh-my-posh >/dev/null 2>&1; then
  export POSH_THEME="$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"
  eval "$(oh-my-posh init bash --config "$POSH_THEME" --strict)"
fi

[[ ${BLE_VERSION-} ]] && ble-attach
