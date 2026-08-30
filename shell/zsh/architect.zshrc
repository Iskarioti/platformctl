# Systems & Platform Architect - managed Zsh shell fragment.
# Source this from ~/.zshrc after normal distro defaults.

export PATH="$HOME/.local/bin:$PATH"
export EDITOR="code --wait"
export VISUAL="$EDITOR"
export LESS="-R"
export PAGER="less"
export VIRTUAL_ENV_DISABLE_PROMPT=1
export POSH_THEME="$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=200000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS HIST_VERIFY HIST_EXPIRE_DUPS_FIRST EXTENDED_HISTORY
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT INTERACTIVE_COMMENTS

autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh"

# fzf compatibility: newer upstream supports `fzf --zsh`; Ubuntu 24.04
# distro packages expose shell integration as files under /usr/share/doc/fzf.
if command -v fzf >/dev/null 2>&1; then
  if fzf --help 2>&1 | grep -q -- '--zsh'; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

export FZF_DEFAULT_OPTS='--height 60% --layout=reverse --border --info=inline'
if command -v fd >/dev/null 2>&1; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
fi

command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# Governed Dev Containers forward this agent's socket in as SSH_AUTH_SOCK
# rather than mounting private keys directly - see ensure-ssh-agent.sh.
if [[ -r "$HOME/.config/workstation/repo-path" ]]; then
  "$(cat "$HOME/.config/workstation/repo-path")/scripts/posix/ensure-ssh-agent.sh" 2>/dev/null
fi
export SSH_AUTH_SOCK="$HOME/.ssh/agent.sock"

if command -v eza >/dev/null 2>&1; then
  alias ls='eza'
  alias l='eza -lah --group-directories-first'
  alias ll='eza -lah --group-directories-first --git'
  alias lt='eza --tree --level=2 --group-directories-first'
  alias lta='eza --tree --level=3 --all --group-directories-first'
else
  alias l='ls -lah'
  alias ll='ls -lah'
fi
command -v bat >/dev/null 2>&1 && alias cat='bat --paging=never'

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
command -v btop >/dev/null 2>&1 && alias top='btop'

ccompany()    { cd "$HOME/src/company" || return; }
cplatform()   { cd "$HOME/src/platform" || return; }
cautomation() { cd "$HOME/src/automation" || return; }
clabs()       { cd "$HOME/src/labs" || return; }
ctooling()    { cd "$HOME/src/tooling" || return; }

mkcd() { mkdir -p "$1" && cd "$1"; }

croot() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null)" || return 1
  cd "$root" || return
}

workspace() {
  local root="$HOME/src"
  local selected

  mkdir -p "$root/company" "$root/platform" "$root/automation" "$root/labs" "$root/tooling"

  if ! command -v fzf >/dev/null 2>&1; then
    cd "$root" || return
    return
  fi

  selected="$({
    printf '%s\n' "$root/company" "$root/platform" "$root/automation" "$root/labs" "$root/tooling"
    find "$root" -mindepth 2 -maxdepth 3 -type d 2>/dev/null
  } | sort -u | fzf --prompt='Workspace> ' --height=60% --layout=reverse --border)"

  [[ -n "$selected" ]] && cd "$selected"
}

project() {
  local dir
  if ! command -v fzf >/dev/null 2>&1; then
    cd "$HOME/src" || return
    return
  fi

  dir="$(find "$HOME/src" -mindepth 1 -maxdepth 4 -type d -name .git -printf '%h\n' 2>/dev/null | sort -u | fzf --prompt='Project> ' --height=60% --layout=reverse --border)"
  [[ -n "$dir" ]] && cd "$dir"
}

gbs() {
  local branch
  branch="$(git branch --all --format='%(refname:short)' 2>/dev/null | sort -u | fzf --prompt='Branch> ' --height=50% --layout=reverse --border)"
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

# Oh My Posh is the single managed prompt engine.
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config "$POSH_THEME")"
fi
