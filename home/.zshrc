export ZDOTDIR="$HOME/.cache/zsh"
mkdir -p "$ZDOTDIR"

HISTFILE="$ZDOTDIR/history"
HISTSIZE=10000
SAVEHIST=10000

[[ -f "$HOME/.profile" ]] && source "$HOME/.profile"

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

setopt autocd
setopt hist_ignore_all_dups
setopt share_history

autoload -Uz compinit
compinit -d "$ZDOTDIR/zcompdump"

alias ls='eza --icons --group-directories-first'
alias ll='eza --icons --group-directories-first -la'
alias cls='clear'
alias ff='fastfetch'
alias files='dolphin . & disown'
alias s='sudo systemctl'
alias update='yay -Syu'

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi

bindkey '^H' backward-kill-word
bindkey '^[[3;5~' backward-kill-word
bindkey '^L' forward-char
bindkey '^K' up-line-or-beginning-search
bindkey '^J' down-line-or-beginning-search

if [[ -f "$XDG_CONFIG_HOME/zsh/local.zsh" ]]; then
  source "$XDG_CONFIG_HOME/zsh/local.zsh"
fi
