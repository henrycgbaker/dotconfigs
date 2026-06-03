#!/bin/bash

# === METADATA ===
# NAME: block-sensitive-write
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking Write/Edit on sensitive files (private keys, credentials, .env.production)
# CONFIG: CLAUDE_HOOK_FILE_PROTECTION=true  Protect critical files
# ================

CLAUDE_HOOK_FILE_PROTECTION="${CLAUDE_HOOK_FILE_PROTECTION:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_FILE_PROTECTION" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "PreToolUse" ]] || exit 0

tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty')
[[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]] || exit 0

file_path=$(echo "$stdin_data" | jq -r '.tool_input.file_path // empty')

deny() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": $escaped}}"
    exit 0
}

if [[ "$file_path" =~ \.pem$ ]]; then
    deny "File protection: Cannot write to .pem files (private keys)"
fi

if [[ "$file_path" =~ credentials ]]; then
    deny "File protection: Cannot write to files containing credentials"
fi

if [[ "$file_path" == *".env.production"* ]]; then
    deny "File protection: Cannot write to .env.production (production secrets)"
fi

if [[ "$file_path" =~ id_rsa$ || "$file_path" =~ id_ed25519$ ]]; then
    deny "File protection: Cannot write to SSH private keys"
fi

exit 0
