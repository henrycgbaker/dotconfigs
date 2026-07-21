# dotconfigs shell aliases (bash + zsh)
# Sourced by both ~/.zshrc and ~/.bashrc via ~/.dotconfigs/shell/aliases.sh.

# Tool replacements
# Debian/Ubuntu ships bat's binary as `batcat` (name conflict with an older package)
if command -v bat &>/dev/null; then
    alias cat='bat'
elif command -v batcat &>/dev/null; then
    alias cat='batcat'
fi
command -v eza &>/dev/null && alias ls="eza --icons --group-directories-first"

# Claude Code (native installer layout; no-ops on a machine without it)
[ -x "$HOME/.claude/local/claude" ] && alias claude="$HOME/.claude/local/claude"

# PATH
export PATH="$HOME/.local/bin:$PATH"
[ -d "/Applications/Visual Studio Code.app" ] && \
    export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"

# Ultrawide monitor resolution shortcuts (this Mac's displays only)
if command -v displayplacer &>/dev/null; then
    alias ultrawide-default='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:3840x1080 hz:60 color_depth:8"'
    alias ultrawide-full='displayplacer "id:DF3652F4-5F79-506F-4047-1FBE06F5DA58 res:5120x1440 hz:60 color_depth:8"'
fi

# SSH tunnels
alias grafana-tunnel='ssh -fNL 3000:localhost:3000 dsl'

# Machine-local customisations - host-specific aliases, tunnels and paths that
# should NOT be shared across machines. Untracked; lives only on this box.
# Sourced last so it can override anything above.
[ -f "$HOME/.dotconfigs.local.sh" ] && . "$HOME/.dotconfigs.local.sh"
