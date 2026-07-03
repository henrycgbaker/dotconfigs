# dotconfigs shell aliases
# Source from .zshrc: source ~/.dotconfigs/shell/aliases.zsh

# Tool replacements
# Debian/Ubuntu ships bat's binary as `batcat` (name conflict with an older package)
if command -v bat &>/dev/null; then
    alias cat='bat'
elif command -v batcat &>/dev/null; then
    alias cat='batcat'
fi
alias ls="eza --icons --group-directories-first"

# Claude Code
alias claude="$HOME/.claude/local/claude"

# PATH
export PATH="$HOME/.local/bin:$PATH"
export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Ultrawide monitor resolution shortcuts
alias ultrawide-default='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:3840x1080 hz:60 color_depth:8"'
alias ultrawide-full='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:5120x1440 hz:60 color_depth:8"'

# SSH tunnels
alias grafana-tunnel='ssh -fNL 3000:localhost:3000 dsl'
