#!/usr/bin/env bash
# Claude Code PostToolUse hook: facade orphan-export guard.
#
# Reads the tool payload from stdin; if the edited file is an __init__.py
# under src/, runs the orphan-export check. Exit 2 surfaces the failure
# back to Claude so it can fix immediately.
#
# Project-agnostic: relies on check-facade-consumers.py auto-detecting
# facades in the repo.

set -e
payload=$(cat)
file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
    */src/*/__init__.py)
        if ! python3 "$CLAUDE_PROJECT_DIR/.git/hooks/check-facade-consumers.py" >&2; then
            exit 2
        fi
        ;;
esac
exit 0
