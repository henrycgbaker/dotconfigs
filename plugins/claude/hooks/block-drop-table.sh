#!/bin/bash

# === METADATA ===
# NAME: block-drop-table
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking DROP TABLE / DROP DATABASE SQL statements (case-insensitive)
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

if echo "$command" | grep -qiE 'DROP\s+(TABLE|DATABASE)'; then
    hook_deny "Destructive command blocked: DROP TABLE/DATABASE (deletes database objects)"
fi

exit 0
