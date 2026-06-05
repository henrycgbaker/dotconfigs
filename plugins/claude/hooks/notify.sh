#!/bin/bash

# === METADATA ===
# NAME: notify
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: Notification hook fanning notifications out to ntfy.sh (if NTFY_TOPIC set) and desktop notify-send (if a display is available). Terminal bell is handled by settings.json preferredNotifChannel.
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

stdin_data=$(cat)
[[ "$(echo "$stdin_data" | jq -r '.hook_event_name // empty')" == "Notification" ]] || exit 0

message=$(echo "$stdin_data" | jq -r '.message // empty')
[[ -n "$message" ]] || exit 0

# ntfy.sh fan-out — only if topic is configured (user-set, not committed).
if [[ -n "$NTFY_TOPIC" ]]; then
    if command -v curl >/dev/null 2>&1; then
        curl -sf -d "$message" "https://ntfy.sh/$NTFY_TOPIC" >/dev/null 2>&1 || true
    fi
fi

# Desktop notify-send — only if there's a display and the tool is installed.
if { [[ -n "$DISPLAY" ]] || [[ -n "$WAYLAND_DISPLAY" ]]; } \
    && command -v notify-send >/dev/null 2>&1; then
    notify-send "Claude Code" "$message" >/dev/null 2>&1 || true
fi

exit 0
