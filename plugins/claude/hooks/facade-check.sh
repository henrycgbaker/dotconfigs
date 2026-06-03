#!/usr/bin/env bash
# Claude Code PostToolUse hook: facade orphan-export guard.
#
# Reads the tool payload from stdin; if the edited file is an __init__.py
# under src/, runs the orphan-export check. Exit 2 surfaces the failure
# back to Claude so it can fix immediately.
#
# Cross-plugin runtime dependency (intentional):
#   The check logic lives in `check-facade-consumers.py`, which the **git
#   plugin** deploys to `$CLAUDE_PROJECT_DIR/.git/hooks/` for use as a git
#   pre-commit hook. This Claude hook reuses the same script at edit time.
#   The dependency is a runtime path lookup at a stable deploy target — not
#   a source-code import — so the "plugins self-contained" rule still holds
#   (each plugin's source files are independent; only the runtime deploy
#   layouts converge on the same target path).
#
# If the python script isn't present (e.g. git plugin not deployed, or the
# project isn't using the facade pattern), this hook is a graceful no-op.

set -e
payload=$(cat)
[[ "$(printf '%s' "$payload" | jq -r '.hook_event_name // empty')" == "PostToolUse" ]] || exit 0

file_path=$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty')

case "$file_path" in
    */src/*/__init__.py)
        helper="$CLAUDE_PROJECT_DIR/.git/hooks/check-facade-consumers.py"
        if [[ -f "$helper" ]]; then
            if ! python3 "$helper" >&2; then
                exit 2
            fi
        fi
        ;;
esac
exit 0
