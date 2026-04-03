# ─────────────────────────────────────────────────────────────────────
#  「✦ FISH CONFIG ✦ 」
# ─────────────────────────────────────────────────────────────────────

set -gx XDG_CONFIG_HOME "$HOME/.config"
set -gx XDG_CACHE_HOME "$HOME/.cache"
set -gx XDG_DATA_HOME "$HOME/.local/share"
set -gx XDG_STATE_HOME "$HOME/.local/state"

# ── INTERACTIVE SHELL ────────────────────────────────────────────────
if status is-interactive
    set fish_greeting ""

    if command -q fastfetch
        fastfetch --logo none
    end
end

# ── ALIASES ──────────────────────────────────────────────────────────
alias ls 'eza --icons --group-directories-first'
alias ll 'eza --icons --group-directories-first -la'
alias ff fastfetch
alias cls clear
alias files 'dolphin . & disown'
alias s 'sudo systemctl'
alias update 'yay -Syu'

# ── KEY BINDINGS ─────────────────────────────────────────────────────
function fish_user_key_bindings
    bind ctrl-backspace backward-kill-word repaint
    bind alt-backspace backward-kill-word repaint
end

# ── TOOL INITIALIZATION ──────────────────────────────────────────────
if status is-interactive
    if command -q starship
        starship init fish | source
    end

    if command -q zoxide
        zoxide init fish | source
    end
end

# ── ENVIRONMENT ──────────────────────────────────────────────────────
fish_add_path $HOME/.local/bin

if command -q nvim
    set -gx EDITOR nvim
else if command -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end

set -gx VISUAL $EDITOR

if test -f "$XDG_CONFIG_HOME/fish/config.local.fish"
    source "$XDG_CONFIG_HOME/fish/config.local.fish"
end
