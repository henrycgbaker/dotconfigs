#!/bin/bash

# === METADATA ===
# NAME: block-drop-table
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking DROP TABLE / DROP DATABASE SQL statements (case-insensitive)
# CONFIG: CLAUDE_HOOK_DESTRUCTIVE_GUARD=true  Guard against destructive commands
# ================

CLAUDE_HOOK_DESTRUCTIVE_GUARD="${CLAUDE_HOOK_DESTRUCTIVE_GUARD:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_DESTRUCTIVE_GUARD" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "PreToolUse" ]] || exit 0

tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty')
[[ "$tool_name" == "Bash" ]] || exit 0

command=$(echo "$stdin_data" | jq -r '.tool_input.command // empty')

deny() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": $escaped}}"
    exit 0
}

if echo "$command" | grep -qiE 'DROP\s+(TABLE|DATABASE)'; then
    deny "Destructive command blocked: DROP TABLE/DATABASE (deletes database objects)"
fi

exit 0
