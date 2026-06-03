#!/bin/bash

# === METADATA ===
# NAME: inject-context
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: UserPromptSubmit hook prepending git context (branch, dirty count, head sha + subject) to every prompt
# CONFIG: CLAUDE_HOOK_PROMPT_CONTEXT=true  Prepend git context to user prompts
# ================

CLAUDE_HOOK_PROMPT_CONTEXT="${CLAUDE_HOOK_PROMPT_CONTEXT:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_PROMPT_CONTEXT" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0
command -v git >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "UserPromptSubmit" ]] || exit 0

# Resolve project directory; fall back to cwd
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# No-op gracefully outside git repos
if ! git -C "$project_dir" rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
dirty=$(git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
sha=$(git -C "$project_dir" rev-parse --short HEAD 2>/dev/null)
subject=$(git -C "$project_dir" log -1 --pretty=%s 2>/dev/null)

context="[context: branch=${branch} | dirty=${dirty} modified | head=${sha} ${subject}]"

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
exit 0
