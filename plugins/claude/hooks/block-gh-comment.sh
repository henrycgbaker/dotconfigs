#!/bin/bash

# === METADATA ===
# NAME: block-gh-comment
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking unsolicited GitHub comment/review posts across two entrypoints - the gh CLI (Bash) and the GitHub MCP server (mcp__github__*). gh writes are denied unless prefixed GH_COMMENT_OK=1; MCP comment/review writes return "ask" for interactive approval.
# CONFIG: CLAUDE_HOOK_GH_COMMENT_GUARD=true  Guard against unsolicited GitHub PR/issue comment posts
# ================
#
# Why: Posting comments/reviews to GitHub PRs/issues is user-facing
# communication that emails notifications which can't be retracted, even after
# deletion. The user replies to reviewers themselves; the assistant pushes code
# and reports to the user in chat. Scope is intentionally the *notification
# surface* - comments, review submissions, replies - and nothing else: other
# GitHub writes (create/edit/merge/label/release/...) are allowed.
#   - gh CLI (Bash):  blocked outright; prefix GH_COMMENT_OK=1 to post after approval.
#   - GitHub MCP:     returns "ask" so the user approves the exact tool + args interactively
#                     (an env-var prefix can't ride along on an MCP tool call).

CLAUDE_HOOK_GH_COMMENT_GUARD="${CLAUDE_HOOK_GH_COMMENT_GUARD:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

if [[ "$CLAUDE_HOOK_GH_COMMENT_GUARD" != "true" ]]; then
    exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
    exit 0
fi

stdin_data=$(cat)
tool_name=$(echo "$stdin_data" | jq -r '.tool_name // empty')

deny() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"deny\", \"permissionDecisionReason\": $escaped}}"
    exit 0
}

ask_user() {
    local reason="$1"
    local escaped
    escaped=$(printf '%s' "$reason" | jq -Rs '.')
    echo "{\"hookSpecificOutput\": {\"hookEventName\": \"PreToolUse\", \"permissionDecision\": \"ask\", \"permissionDecisionReason\": $escaped}}"
    exit 0
}

# === GitHub MCP server: mcp__github__* ===
# A comment/review post = a write verb (add/create/submit/reply/update) plus a
# "comment" or "review" keyword. This matches add_issue_comment,
# *_pull_request_review, add_comment_to_pending_review, etc., while excluding
# reads (get_/list_/search_*comments*) and non-comment writes (create_pull_request,
# update_issue, merge_pull_request, label/release ops, ...). Returns "ask" so the
# user approves the exact tool + args interactively.
if [[ "$tool_name" == mcp__github__* ]]; then
    if echo "$tool_name" | grep -qE '^mcp__github__(add|create|submit|reply|update)_.*(comment|review)'; then
        ask_user "GitHub MCP comment/review post (${tool_name}): user-facing content that emails notifications and can't be retracted. Approve only if the user explicitly asked you to post; otherwise report in chat or hand them the gh command."
    fi
    exit 0
fi

# === gh CLI via Bash ===
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$stdin_data" | jq -r '.tool_input.command // empty')

if [[ -z "$command" ]]; then
    exit 0
fi

# Explicit bypass: GH_COMMENT_OK=1 anywhere in the command (env var prefix or inline).
if echo "$command" | grep -qE '(^|[^A-Z_])GH_COMMENT_OK=1(\s|$)'; then
    exit 0
fi

BYPASS_HINT="To override after explicit user approval, prefix the command: GH_COMMENT_OK=1 <command>"

# gh pr comment / gh issue comment — direct write operations.
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+(pr|issue)\s+comment(\s|$)'; then
    deny "Blocked GitHub write: gh pr/issue comment posts user-facing content. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

# gh pr review — without --web this submits a review (approve/request-changes/comment).
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+pr\s+review(\s|$)' && ! echo "$command" | grep -qE -- '--web(\s|$)'; then
    deny "Blocked GitHub write: gh pr review submits a review. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

# gh api writes against PR/issue comment, review, or reply endpoints (incl. a
# standalone comment by id, e.g. /repos/.../issues/comments/<id>).
#
# A write is either an explicit write method (-X / --method POST|PATCH|PUT) OR
# gh's *implicit* POST: gh api defaults to GET but switches to POST as soon as
# any body param is supplied (-f/-F/--field/--raw-field/--input), so a reply can
# be posted with no -X at all. An explicit -X/--method GET is always a read,
# even when body params are present, so it is not blocked.
if echo "$command" | grep -qE '(^|[^A-Za-z0-9_])gh\s+api\b' \
   && echo "$command" | grep -qE '/(pulls|issues)/(comments/[0-9]+(/replies)?|[0-9]+/(comments|reviews|replies))' \
   && { echo "$command" | grep -qE -- '(-X|--method)\s*(POST|PATCH|PUT)\b' \
        || { echo "$command" | grep -qE -- '(^|\s)(-f|-F|--field|--raw-field|--input)(\s|=)' \
             && ! echo "$command" | grep -qE -- '(-X|--method)\s*GET\b'; }; }; then
    deny "Blocked GitHub write: gh api write (explicit -X/--method POST|PATCH|PUT, or implicit POST via -f/-F/--field/--raw-field/--input) to PR/issue comments|reviews|replies. Ask the user explicitly before posting. ${BYPASS_HINT}"
fi

exit 0
