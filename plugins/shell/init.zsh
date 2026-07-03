# dotconfigs shell init — tool initialisations
# Source from .zshrc: source ~/.dotconfigs/shell/init.zsh
# Each tool is guarded so a fresh machine that hasn't installed everything
# yet gets a silent no-op instead of an error on every new shell.

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# zoxide (smarter cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# fzf key bindings and completion
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# thefuck
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"

# conda
__conda_setup="$("$HOME/miniconda3/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
elif [ -f "$HOME/miniconda3/etc/profile.d/conda.sh" ]; then
    . "$HOME/miniconda3/etc/profile.d/conda.sh"
else
    export PATH="$HOME/miniconda3/bin:$PATH"
fi
unset __conda_setup

# zsh-autosuggestions + zsh-syntax-highlighting (must be sourced last, in this order)
if command -v brew &>/dev/null; then
    _brew_prefix="$(brew --prefix)"
    [ -f "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ] && \
        source "$_brew_prefix/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
    [ -f "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] && \
        source "$_brew_prefix/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
    unset _brew_prefix
fi
