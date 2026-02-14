#!/bin/bash

# === METADATA ===
# NAME: block-destructive
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook to block destructive commands and protect sensitive files
# CONFIG: CLAUDE_HOOK_DESTRUCTIVE_GUARD=true  Guard against destructive commands
# CONFIG: CLAUDE_HOOK_FILE_PROTECTION=true  Protect critical files
# ================

# Config loading with hierarchy: defaults → env vars → config file
CLAUDE_HOOK_DESTRUCTIVE_GUARD="${CLAUDE_HOOK_DESTRUCTIVE_GUARD:-true}"
CLAUDE_HOOK_FILE_PROTECTION="${CLAUDE_HOOK_FILE_PROTECTION:-true}"

# Try config files in order (project overrides global)
if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

# Verify jq is available (required for JSON parsing)
if ! command -v jq >/dev/null 2>&1; then
    # Silent exit — don't block workflow if jq missing
    exit 0
fi

# Read JSON from stdin
stdin_data=$(cat)

# Extract tool name and input
tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty')
tool_input=$(echo "$stdin_data" | jq -c '.tool_input // {}')

# Deny helper — outputs new-format PreToolUse deny decision
deny() {
    local reason="$1"
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": \"$reason\"}}"
    exit 0
}

# -----------------------------------------------------------------------------
# Destructive Command Guard (Bash tool)
# -----------------------------------------------------------------------------

if [[ "$CLAUDE_HOOK_DESTRUCTIVE_GUARD" == "true" ]] && [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command // empty')

    # Check for destructive patterns
    if echo "$command" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*\s+)?(-[a-zA-Z]*f[a-zA-Z]*\s+)?(/\s*$|~/\s*$)'; then
        deny "Destructive command blocked: rm -rf / or rm -rf ~ (deletes entire filesystem)"
    fi

    if echo "$command" | grep -qE 'git\s+push.*--force(\s|$)' && ! echo "$command" | grep -qE '--force-with-lease'; then
        deny "Destructive command blocked: git push --force without --force-with-lease (can overwrite others work)"
    fi

    if echo "$command" | grep -qE 'git\s+reset\s+--hard'; then
        deny "Destructive command blocked: git reset --hard (discards uncommitted work)"
    fi

    if echo "$command" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f[a-zA-Z]*[a-zA-Z]*d'; then
        deny "Destructive command blocked: git clean -fd (deletes untracked files)"
    fi

    if echo "$command" | grep -qiE 'DROP\s+(TABLE|DATABASE)'; then
        deny "Destructive command blocked: DROP TABLE/DATABASE (deletes database objects)"
    fi

    if echo "$command" | grep -qE 'chmod\s+-R\s+777'; then
        deny "Destructive command blocked: chmod -R 777 (creates security vulnerability)"
    fi
fi

# -----------------------------------------------------------------------------
# File Protection (Write/Edit tools)
# -----------------------------------------------------------------------------

if [[ "$CLAUDE_HOOK_FILE_PROTECTION" == "true" ]] && [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path // empty')

    # Check for sensitive file patterns
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
fi

# No match — implicit allow (exit 0 with no output)
exit 0
