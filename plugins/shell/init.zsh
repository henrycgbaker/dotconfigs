# dotconfigs shell init — tool initialisations
# Source from .zshrc: source ~/.dotconfigs/shell/init.zsh
# Each tool is guarded so a fresh machine that hasn't installed everything
# yet gets a silent no-op instead of an error on every new shell.

# typeset -U keeps PATH deduplicated - this file, aliases.zsh, and the conda/
# VS Code branches below all prepend their own entries, and a re-sourced shell
# (e.g. a nested bash -> zsh handoff) would otherwise grow PATH on every level.
typeset -U path PATH

# ~/.local/bin is where user-local tool installers (starship, zoxide, etc.)
# land. This file is sourced before aliases.zsh (which also exports this),
# so the guards below need their own copy - otherwise, on any machine whose
# .bashrc/.profile chain doesn't already put ~/.local/bin on PATH before
# .zshrc runs, every "command -v" guard here would silently miss a
# user-locally-installed tool.
export PATH="$HOME/.local/bin:$PATH"

# Starship prompt
command -v starship &>/dev/null && eval "$(starship init zsh)"

# zoxide (smarter cd)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# fzf key bindings and completion
# Checked in both layouts: the git-installer/curl layout (~/.fzf.zsh) and
# the apt package layout (/usr/share/doc/fzf/examples/*.zsh).
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# thefuck
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"

# conda (miniconda, anaconda, or miniforge - whichever is actually installed)
for _conda_root in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" "$HOME/mambaforge"; do
    if [ -f "$_conda_root/bin/conda" ]; then
        __conda_setup="$("$_conda_root/bin/conda" 'shell.zsh' 'hook' 2> /dev/null)"
        if [ $? -eq 0 ]; then
            eval "$__conda_setup"
        elif [ -f "$_conda_root/etc/profile.d/conda.sh" ]; then
            . "$_conda_root/etc/profile.d/conda.sh"
        else
            export PATH="$_conda_root/bin:$PATH"
        fi
        unset __conda_setup
        break
    fi
done
unset _conda_root

# zsh-autosuggestions + zsh-syntax-highlighting (must be sourced last, in this order)
# Checked in share dirs, not by OS: Homebrew's prefix (mac, or Linuxbrew) first,
# then /usr/share (e.g. Debian/Ubuntu apt packages) — whichever actually has the file wins.
_zsh_plugin_share_dirs=(/usr/share)
command -v brew &>/dev/null && _zsh_plugin_share_dirs=("$(brew --prefix)/share" $_zsh_plugin_share_dirs)
for _plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    for _dir in $_zsh_plugin_share_dirs; do
        [ -f "$_dir/$_plugin/$_plugin.zsh" ] && source "$_dir/$_plugin/$_plugin.zsh" && break
    done
done
unset _zsh_plugin_share_dirs _dir _plugin
