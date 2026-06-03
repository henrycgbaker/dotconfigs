#!/bin/bash

# === METADATA ===
# NAME: session-end-log
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: SessionEnd hook appending a JSONL telemetry line to ~/.claude/session-log.jsonl (timestamp, session_id, duration, model, project_dir)
# CONFIG: CLAUDE_HOOK_SESSION_LOG=true  Append session telemetry to ~/.claude/session-log.jsonl
# ================

CLAUDE_HOOK_SESSION_LOG="${CLAUDE_HOOK_SESSION_LOG:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_SESSION_LOG" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "SessionEnd" ]] || exit 0

session_id=$(echo "$stdin_data" | jq -r '.session_id // empty')
duration=$(echo "$stdin_data" | jq -r '.duration_seconds // empty')
model=$(echo "$stdin_data" | jq -r '.model // empty')
project_dir=$(echo "$stdin_data" | jq -r '.cwd // empty')
[[ -z "$project_dir" ]] && project_dir="$CLAUDE_PROJECT_DIR"
timestamp=$(date -u +%FT%TZ)

log_file="$HOME/.claude/session-log.jsonl"
mkdir -p "$(dirname "$log_file")"

jq -n -c \
    --arg ts "$timestamp" \
    --arg sid "$session_id" \
    --arg dur "$duration" \
    --arg model "$model" \
    --arg pd "$project_dir" \
    '{timestamp: $ts, session_id: $sid, duration_seconds: $dur, model: $model, project_dir: $pd}' \
    >> "$log_file"

exit 0
