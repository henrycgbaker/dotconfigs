#!/bin/bash

# === METADATA ===
# NAME: block-hard-reset
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking git reset --hard (discards uncommitted work)
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

stdin_data=$(cat)
{
    IFS= read -r hook_event
    IFS= read -r tool_name
    IFS= read -r command
} < <(echo "$stdin_data" | jq -r '.hook_event_name // "", .tool_name // "", .tool_input.command // ""')

[[ "$hook_event" == "PreToolUse" ]] || exit 0
[[ "$tool_name" == "Bash" ]] || exit 0

if echo "$command" | grep -qE 'git\s+reset\s+--hard'; then
    hook_deny "Destructive command blocked: git reset --hard (discards uncommitted work)"
fi

exit 0
