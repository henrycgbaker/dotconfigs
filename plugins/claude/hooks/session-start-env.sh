#!/bin/bash

# === METADATA ===
# NAME: session-start-env
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: SessionStart hook auto-activating a Python .venv in $CLAUDE_PROJECT_DIR by writing VIRTUAL_ENV and PATH to $CLAUDE_ENV_FILE
# CONFIG: CLAUDE_HOOK_VENV_AUTO=true  Auto-activate Python .venv on session start
# ================

CLAUDE_HOOK_VENV_AUTO="${CLAUDE_HOOK_VENV_AUTO:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_VENV_AUTO" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "SessionStart" ]] || exit 0

# CLAUDE_ENV_FILE is the harness-provided file we append KEY=value lines to.
[[ -n "$CLAUDE_ENV_FILE" ]] || exit 0
[[ -n "$CLAUDE_PROJECT_DIR" ]] || exit 0

venv_dir="$CLAUDE_PROJECT_DIR/.venv"
[[ -f "$venv_dir/bin/activate" ]] || exit 0

printf 'VIRTUAL_ENV=%s\n' "$venv_dir" >> "$CLAUDE_ENV_FILE"
printf 'PATH=%s/bin:%s\n' "$venv_dir" "$PATH" >> "$CLAUDE_ENV_FILE"

exit 0
