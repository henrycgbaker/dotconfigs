#!/bin/bash

# === METADATA ===
# NAME: pre-compact-snapshot
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreCompact hook snapshotting the transcript to ~/.claude/snapshots/<session_id>-precompact.jsonl before compaction
# CONFIG: CLAUDE_HOOK_PRECOMPACT_SNAPSHOT=true  Snapshot transcript before compaction
# ================

CLAUDE_HOOK_PRECOMPACT_SNAPSHOT="${CLAUDE_HOOK_PRECOMPACT_SNAPSHOT:-true}"

if [[ -f "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$CLAUDE_PROJECT_DIR/.claude/claude-hooks.conf"
elif [[ -f "$HOME/.claude/claude-hooks.conf" ]]; then
    # shellcheck source=/dev/null
    source "$HOME/.claude/claude-hooks.conf"
fi

[[ "$CLAUDE_HOOK_PRECOMPACT_SNAPSHOT" == "true" ]] || exit 0
command -v jq >/dev/null 2>&1 || exit 0

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "PreCompact" ]] || exit 0

transcript_path=$(echo "$stdin_data" | jq -r '.transcript_path // empty')
session_id=$(echo "$stdin_data" | jq -r '.session_id // empty')

[[ -n "$transcript_path" && -n "$session_id" ]] || exit 0
[[ -f "$transcript_path" ]] || exit 0

snapshot_dir="$HOME/.claude/snapshots"
mkdir -p "$snapshot_dir"
cp "$transcript_path" "$snapshot_dir/${session_id}-precompact.jsonl"

exit 0
