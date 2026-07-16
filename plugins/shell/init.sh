# dotconfigs shell init — tool initialisations (bash + zsh)
# Sourced by both ~/.zshrc and ~/.bashrc via ~/.dotconfigs/shell/init.sh.
# Each tool is guarded so a fresh machine that hasn't installed everything
# yet gets a silent no-op instead of an error on every new shell.

# Which shell are we in? Tool `init` sub-commands and completion files are
# shell-specific ("starship init bash" vs "…zsh"), so most of this file
# parameterises on $_sh. Left empty for any other POSIX shell, in which case
# the shell-specific blocks below no-op and only the portable bits run.
if [ -n "$ZSH_VERSION" ]; then
    _sh=zsh
elif [ -n "$BASH_VERSION" ]; then
    _sh=bash
else
    _sh=
fi

# zsh keeps PATH deduplicated natively (typeset -U); bash has no equivalent, so
# on bash a nested re-source can grow PATH. That's cosmetic (dupes are
# harmless) and the handoff means bash is usually short-lived, so we don't
# emulate it. Guarded because `typeset -U` would corrupt PATH in bash (there
# -U means uppercase-on-assignment).
[ -n "$ZSH_VERSION" ] && typeset -U path PATH

# ~/.local/bin is where user-local tool installers (starship, zoxide, etc.)
# land. This file is sourced before aliases.sh (which also exports this), so
# the guards below need their own copy - otherwise, on any machine whose
# startup chain doesn't already put ~/.local/bin on PATH before this file
# runs, every "command -v" guard here would silently miss a user-locally-
# installed tool.
export PATH="$HOME/.local/bin:$PATH"

# Starship prompt
[ -n "$_sh" ] && command -v starship &>/dev/null && eval "$(starship init "$_sh")"

# zoxide (smarter cd)
[ -n "$_sh" ] && command -v zoxide &>/dev/null && eval "$(zoxide init "$_sh")"

# fzf key bindings and completion.
# Checked in both layouts: the git-installer/curl layout (~/.fzf.$_sh) and the
# apt package layout (/usr/share/doc/fzf/examples/*.$_sh).
if [ -n "$_sh" ]; then
    if [ -f "$HOME/.fzf.$_sh" ]; then
        source "$HOME/.fzf.$_sh"
    elif [ -f "/usr/share/doc/fzf/examples/key-bindings.$_sh" ]; then
        source "/usr/share/doc/fzf/examples/key-bindings.$_sh"
        [ -f "/usr/share/doc/fzf/examples/completion.$_sh" ] && \
            source "/usr/share/doc/fzf/examples/completion.$_sh"
    fi
fi

# thefuck — its --alias output defines a function that works in bash and zsh
# alike, so no per-shell branch is needed.
command -v thefuck &>/dev/null && eval "$(thefuck --alias)"

# conda (miniconda, anaconda, or miniforge - whichever is actually installed).
# "shell.$_sh hook" is the shell-specific entry point; falls back to posix for
# any other shell, and to conda.sh / bare PATH if the hook is unavailable.
for _conda_root in "$HOME/miniconda3" "$HOME/anaconda3" "$HOME/miniforge3" "$HOME/mambaforge"; do
    if [ -f "$_conda_root/bin/conda" ]; then
        __conda_setup="$("$_conda_root/bin/conda" "shell.${_sh:-posix}" hook 2> /dev/null)"
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

# zsh-only line-editor plugins (bash has no drop-in equivalent). Must be
# sourced last, in this order. Checked in share dirs, not by OS: Homebrew's
# prefix (mac, or Linuxbrew) first, then /usr/share (e.g. Debian/Ubuntu apt).
if [ -n "$ZSH_VERSION" ]; then
    _zsh_plugin_share_dirs=(/usr/share)
    command -v brew &>/dev/null && _zsh_plugin_share_dirs=("$(brew --prefix)/share" $_zsh_plugin_share_dirs)
    for _plugin in zsh-autosuggestions zsh-syntax-highlighting; do
        for _dir in $_zsh_plugin_share_dirs; do
            [ -f "$_dir/$_plugin/$_plugin.zsh" ] && source "$_dir/$_plugin/$_plugin.zsh" && break
        done
    done
    unset _zsh_plugin_share_dirs _dir _plugin
fi

unset _sh
