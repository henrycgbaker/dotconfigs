#!/bin/bash

# === METADATA ===
# NAME: block-force-push
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking git push --force without --force-with-lease
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

if echo "$command" | grep -qE 'git\s+push.*--force(\s|$)' && ! echo "$command" | grep -qE '--force-with-lease'; then
    hook_deny "Destructive command blocked: git push --force without --force-with-lease (can overwrite others work)"
fi

exit 0
