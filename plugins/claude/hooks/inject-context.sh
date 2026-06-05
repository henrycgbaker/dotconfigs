#!/bin/bash

# === METADATA ===
# NAME: inject-context
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: UserPromptSubmit hook prepending git context (branch, dirty count, head sha + subject) to every prompt
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

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

# Batched git calls: `status --branch --porcelain` returns branch + dirty
# in one process; `log -1` returns sha + subject in one process.
# Total: 2 git invocations instead of the original 4 (~50% reduction on
# every prompt).
status_output=$(git -C "$project_dir" status --branch --porcelain 2>/dev/null)
# First line is "## branch...origin/branch [ahead N]" or "## branch" or
# "## HEAD (no branch)"; strip "## " prefix and everything from "..." on.
branch=$(printf '%s\n' "$status_output" | awk 'NR==1 {sub(/^## /, ""); sub(/\.\.\..*$/, ""); print; exit}')
# Remaining lines are dirty entries.
dirty=$(printf '%s\n' "$status_output" | tail -n +2 | grep -c .)
{
    IFS= read -r sha
    IFS= read -r subject
} < <(git -C "$project_dir" log -1 --format='%h%n%s' 2>/dev/null)

context="[context: branch=${branch} | dirty=${dirty} modified | head=${sha} ${subject}]"

jq -n --arg ctx "$context" '{hookSpecificOutput: {hookEventName: "UserPromptSubmit", additionalContext: $ctx}}'
exit 0
