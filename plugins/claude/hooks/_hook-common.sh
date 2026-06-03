#!/bin/bash
# _hook-common.sh - Shared helpers for Claude Code hook scripts.
#
# Sourced from each hook via:
#   source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"
#
# Centralises three patterns that otherwise repeated in every hook:
#   - loading user-configurable toggles from claude-hooks.conf
#     (project conf overrides global)
#   - tool-presence checks
#   - JSON-escaped deny/ask emission for PreToolUse decisions

# Load user-configurable hook toggles. Project conf overrides global.
hook_load_conf() {
    if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
        # shellcheck source=/dev/null
        source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
    elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
        # shellcheck source=/dev/null
        source "$HOME/.claude/claude-hooks.conf"
    fi
}

# Silently no-op the hook if a required command is missing.
hook_require_cmd() {
    command -v "$1" >/dev/null 2>&1 || exit 0
}

# Emit a PreToolUse deny decision with JSON-escaped reason text.
hook_deny() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "deny", "permissionDecisionReason": %s}}\n' "$escaped"
    exit 0
}

# Emit a PreToolUse ask decision (interactive permission prompt).
hook_ask() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    printf '{"hookSpecificOutput": {"hookEventName": "PreToolUse", "permissionDecision": "ask", "permissionDecisionReason": %s}}\n' "$escaped"
    exit 0
}
