# Minimal zsh configuration with devbox integration

#--------------------------
# Devbox Global
#--------------------------
# Load devbox global environment
eval "$(devbox global shellenv)"

#--------------------------
# History
#--------------------------
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE

#--------------------------
# Options
#--------------------------
setopt AUTO_CD
setopt CORRECT
setopt NO_BEEP

#--------------------------
# Completion
#--------------------------
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

#--------------------------
# Key bindings
#--------------------------
bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward

#--------------------------
# Aliases
#--------------------------
alias ls='eza --icons'
alias ll='eza -la --icons'
alias la='eza -a --icons'
alias lt='eza --tree --icons'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias vim='nvim'
alias vi='nvim'
alias lg='lazygit'
alias gs='git status'
alias gd='git diff'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline --graph'

#--------------------------
# Tool integrations
#--------------------------
# Zoxide (better cd)
eval "$(zoxide init zsh)"

# FZF
source <(fzf --zsh)

# Starship prompt
eval "$(starship init zsh)"

#--------------------------
# Devbox shell hook
#--------------------------
# Auto-activate devbox when entering a directory with devbox.json
_devbox_hook() {
    if [[ -f "devbox.json" ]] && [[ -z "$DEVBOX_SHELL_ENABLED" ]]; then
        echo "Devbox environment detected. Run 'devbox shell' to activate."
    fi
}
chpwd_functions+=(_devbox_hook)

#--------------------------
# Local overrides
#--------------------------
[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
