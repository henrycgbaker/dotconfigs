#!/bin/bash

# === METADATA ===
# NAME: block-git-clean
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking git clean -fd (and -fdX variants) which deletes untracked files
# CONFIG: CLAUDE_HOOK_DESTRUCTIVE_GUARD=true  Guard against destructive commands
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

CLAUDE_HOOK_DESTRUCTIVE_GUARD="${CLAUDE_HOOK_DESTRUCTIVE_GUARD:-true}"
hook_load_conf

[[ "$CLAUDE_HOOK_DESTRUCTIVE_GUARD" == "true" ]] || exit 0
hook_require_cmd jq

stdin_data=$(cat)
{
    IFS= read -r hook_event
    IFS= read -r tool_name
    IFS= read -r command
} < <(echo "$stdin_data" | jq -r '.hook_event_name // "", .tool_name // "", .tool_input.command // ""')

[[ "$hook_event" == "PreToolUse" ]] || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0

if echo "$command" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f[a-zA-Z]*[a-zA-Z]*d'; then
    hook_deny "Destructive command blocked: git clean -fd (deletes untracked files)"
fi

exit 0
