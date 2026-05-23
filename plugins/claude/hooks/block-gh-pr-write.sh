#!/bin/bash

# === METADATA ===
# NAME: block-gh-pr-write
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook to block GitHub PR/issue write operations (comments, reviews, replies) unless explicitly authorised via GH_PR_COMMENT_OK=1
# CONFIG: CLAUDE_HOOK_GH_PR_WRITE_GUARD=true  Guard against unsolicited GitHub PR/issue writes
# ================
#
# Why: Posting to GitHub PRs/issues is user-facing communication. Even after
# deletion, email notifications cannot be retracted. The user replies to
# reviewers themselves; the assistant pushes code and reports to the user
# in chat. To intentionally post, prefix the command with GH_PR_COMMENT_OK=1.

CLAUDE_HOOK_GH_PR_WRITE_GUARD="${CLAUDE_HOOK_GH_PR_WRITE_GUARD:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

if [[ "$CLAUDE_HOOK_GH_PR_WRITE_GUARD" != "true" ]]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

stdin_data=$(cat)
tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty')

if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$stdin_data" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
    exit 0
fi

deny() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": $escaped}}"
    exit 0
}

# Explicit bypass: GH_PR_COMMENT_OK=1 anywhere in the command (env var prefix or inline).
if echo "$command" | grep -qE '(^|[^A-Z_])GH_PR_COMMENT_OK=1(\s|$)'; then
    exit 0
fi

BYPASS_HINT="To override after explicit user approval, prefix the command: GH_PR_COMMENT_OK=1 <command>"

# gh pr comment / gh issue comment — direct write operations.
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+(pr|issue)\s+comment(\s|$)'; then
    deny "Blocked GitHub write: gh pr/issue comment posts user-facing content. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

# gh pr review — without --web this submits a review (approve/request-changes/comment).
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+pr\s+review(\s|$)' && ! echo "$command" | grep -qE -- '--web(\s|$)'; then
    deny "Blocked GitHub write: gh pr review submits a review. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

# gh api writes against PR/issue comment, review, or reply endpoints.
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+api\b' \
   && echo "$command" | grep -qE -- '-X\s*(POST|PATCH|PUT)\b' \
   && echo "$command" | grep -qE '/(pulls|issues)/(comments/[0-9]+(/replies)?|[0-9]+/(comments|reviews|replies))'; then
    deny "Blocked GitHub write: gh api POST/PATCH/PUT to PR/issue comments|reviews|replies. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

# gh api PATCH/PUT to a standalone comment by id (e.g. /repos/.../issues/comments/<id>).
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+api\b' \
   && echo "$command" | grep -qE -- '-X\s*(PATCH|PUT)\b' \
   && echo "$command" | grep -qE '/(issues|pulls)/comments/[0-9]+(\s|"|$)'; then
    deny "Blocked GitHub write: gh api PATCH/PUT to an existing comment. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

exit 0
