# Systems & Platform Architect zsh layer
export PATH="$HOME/.local/bin:$PATH"
export VIRTUAL_ENV_DISABLE_PROMPT=1
export POSH_THEME="$HOME/.config/oh-my-posh/tokyonight-architect.omp.json"

setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY
HISTSIZE=100000
SAVEHIST=100000
HISTFILE="$HOME/.zsh_history"

autoload -Uz compinit && compinit

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

alias ll='ls -lah'
alias gs='git status'
alias gd='git diff'
alias glog='git log --graph --decorate --oneline --all'
alias k='kubectl'
alias tf='terraform'

if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init zsh --config "$POSH_THEME")"
fi
