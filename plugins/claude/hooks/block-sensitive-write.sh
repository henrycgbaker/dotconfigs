#!/bin/bash

# === METADATA ===
# NAME: block-sensitive-write
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: PreToolUse hook blocking Write/Edit on sensitive files (private keys, credentials, .env.production)
# ================

# shellcheck source=_hook-common.sh
source "$(dirname "${BASH_SOURCE[0]}")/_hook-common.sh"

hook_require_cmd jq

stdin_data=$(cat)
{
    IFS= read -r hook_event
    IFS= read -r tool_name
    IFS= read -r file_path
} < <(echo "$stdin_data" | jq -r '.hook_event_name // "", .tool_name // "", .tool_input.file_path // ""')

[[ "$hook_event" == "PreToolUse" ]] || exit 0
[[ "$tool_name" == "Write" || "$tool_name" == "Edit" ]] || exit 0

if [[ "$file_path" =~ \.pem$ ]]; then
    hook_deny "File protection: Cannot write to .pem files (private keys)"
fi

if [[ "$file_path" =~ credentials ]]; then
    hook_deny "File protection: Cannot write to files containing credentials"
fi

if [[ "$file_path" == *".env.production"* ]]; then
    hook_deny "File protection: Cannot write to .env.production (production secrets)"
fi

if [[ "$file_path" =~ id_rsa$ || "$file_path" =~ id_ed25519$ ]]; then
    hook_deny "File protection: Cannot write to SSH private keys"
fi

exit 0
