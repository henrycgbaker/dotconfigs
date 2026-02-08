#!/bin/bash

# === METADATA ===
# NAME: block-destructive
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook to block destructive commands and protect sensitive files
# CONFIGURABLE: CLAUDE_HOOK_DESTRUCTIVE_GUARD, CLAUDE_HOOK_FILE_PROTECTION
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

# -----------------------------------------------------------------------------
# Destructive Command Guard (Bash tool)
# -----------------------------------------------------------------------------

if [[ "$CLAUDE_HOOK_DESTRUCTIVE_GUARD" == "true" ]] && [[ "$tool_name" == "Bash" ]]; then
    command=$(echo "$tool_input" | jq -r '.command // empty')

    # Check for destructive patterns
    if echo "$command" | grep -qE 'rm\s+(-[a-zA-Z]*r[a-zA-Z]*\s+)?(-[a-zA-Z]*f[a-zA-Z]*\s+)?(/\s*$|~/\s*$)'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: rm -rf / or rm -rf ~ (deletes entire filesystem)"}'
        exit 0
    fi

    if echo "$command" | grep -qE 'git\s+push.*--force(\s|$)' && ! echo "$command" | grep -qE '--force-with-lease'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: git push --force without --force-with-lease (can overwrite others work)"}'
        exit 0
    fi

    if echo "$command" | grep -qE 'git\s+reset\s+--hard'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: git reset --hard (discards uncommitted work)"}'
        exit 0
    fi

    if echo "$command" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f[a-zA-Z]*[a-zA-Z]*d'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: git clean -fd (deletes untracked files)"}'
        exit 0
    fi

    if echo "$command" | grep -qiE 'DROP\s+(TABLE|DATABASE)'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: DROP TABLE/DATABASE (deletes database objects)"}'
        exit 0
    fi

    if echo "$command" | grep -qE 'chmod\s+-R\s+777'; then
        echo '{"decision": "block", "reason": "Destructive command blocked: chmod -R 777 (creates security vulnerability)"}'
        exit 0
    fi
fi

# -----------------------------------------------------------------------------
# File Protection (Write/Edit tools)
# -----------------------------------------------------------------------------

if [[ "$CLAUDE_HOOK_FILE_PROTECTION" == "true" ]] && [[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]]; then
    file_path=$(echo "$tool_input" | jq -r '.file_path // empty')

    # Check for sensitive file patterns
    if [[ "$file_path" =~ \.pem$ ]]; then
        echo '{"decision": "block", "reason": "File protection: Cannot write to .pem files (private keys)"}'
        exit 0
    fi

    if [[ "$file_path" =~ credentials ]]; then
        echo '{"decision": "block", "reason": "File protection: Cannot write to files containing credentials"}'
        exit 0
    fi

    if [[ "$file_path" == *".env.production"* ]]; then
        echo '{"decision": "block", "reason": "File protection: Cannot write to .env.production (production secrets)"}'
        exit 0
    fi

    if [[ "$file_path" =~ id_rsa$ || "$file_path" =~ id_ed25519$ ]]; then
        echo '{"decision": "block", "reason": "File protection: Cannot write to SSH private keys"}'
        exit 0
    fi
fi

# No match — implicit allow (exit 0 with no output)
exit 0
