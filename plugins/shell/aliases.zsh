# dotconfigs shell aliases
# Source from .zshrc: source ~/.dotconfigs/shell/aliases.zsh

# Tool replacements
alias cat='bat'
alias ls='eza'

# Claude Code
alias claude="$HOME/.claude/local/claude"

# PATH
export PATH="$HOME/.local/bin:$PATH"

# Ultrawide monitor resolution shortcuts
alias ultrawide-default='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:3840x1080 hz:60 color_depth:8"'
alias ultrawide-full='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:5120x1440 hz:60 color_depth:8"'

# SSH tunnels
alias grafana-tunnel='ssh -fNL 3000:localhost:3000 dsl'
