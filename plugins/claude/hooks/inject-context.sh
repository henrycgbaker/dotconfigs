#!/bin/bash

# === METADATA ===
# NAME: inject-context
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: UserPromptSubmit hook prepending git context (branch, dirty count, head sha + subject) to every prompt
# CONFIG: CLAUDE_HOOK_PROMPT_CONTEXT=true  Prepend git context to user prompts
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

CLAUDE_HOOK_PROMPT_CONTEXT="${CLAUDE_HOOK_PROMPT_CONTEXT:-true}"
hook_load_conf

[[ "$CLAUDE_HOOK_PROMPT_CONTEXT" == "true" ]] || exit 0
hook_require_cmd jq
hook_require_cmd git

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "UserPromptSubmit" ]] || exit 0

# Resolve project directory; fall back to cwd
project_dir="${CLAUDE_PROJECT_DIR:-$PWD}"

# No-op gracefully outside git repos
if ! git -C "$project_dir" rev-parse --git-dir >/dev/null 2>&1; then
    exit 0
fi

# Batched git calls: one `git log` returns sha + subject in one process.
# Total: 3 git invocations instead of 4 (~25% fewer subprocess spawns on
# every prompt).
branch=$(git -C "$project_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
{
    IFS= read -r sha
    IFS= read -r subject
} < <(git -C "$project_dir" log -1 --format='%h%n%s' 2>/dev/null)
dirty=$(git -C "$project_dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')

context="[context: branch=${branch} | dirty=${dirty} modified | head=${sha} ${subject}]"

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
exit 0
