#!/bin/bash

# === METADATA ===
# NAME: pre-compact-snapshot
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreCompact hook snapshotting the transcript to ~/.claude/snapshots/<session_id>-precompact.jsonl before compaction
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

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
