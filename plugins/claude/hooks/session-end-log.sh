#!/bin/bash

# === METADATA ===
# NAME: session-end-log
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: SessionEnd hook appending a JSONL telemetry line to ~/.claude/session-log.jsonl (timestamp, session_id, duration, model, project_dir)
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

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
    '{timestamp: $ts,
      session_id: $sid,
      duration_seconds: ($dur | tonumber? // null),
      model: $model,
      project_dir: $pd}' \
    >> "$log_file"

exit 0
