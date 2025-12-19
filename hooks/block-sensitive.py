#!/usr/bin/env python3
"""PreToolUse hook to block access to sensitive files.

Blocks Read/Write/Edit operations on sensitive files including:
- Environment files (.env, secrets)
- SSH keys and credentials
- System files (/etc/shadow, /etc/passwd)
- ML credentials (wandb, huggingface, etc.)

Exit codes:
- 0: Allow operation
- 2: Block operation (stderr shown to Claude)
"""

import json
import re
import sys


SENSITIVE_PATTERNS = [
    # Environment files
    r"\.env$",
    r"\.env\.",
    r"\.env\..*",

    # Secrets directories
    r"/secrets/",
    r"\.ssh/",

    # Credential files
    r"_key$",
    r"_key\.",
    r"_secret$",
    r"_secret\.",
    r"credentials",
    r"\.pem$",
    r"\.key$",

    # System files
    r"^/etc/shadow$",
    r"^/etc/passwd$",
    r"^/etc/sudoers",

    # ML credentials
    r"wandb_key",
    r"\.wandb/",
    r"hf_token",
    r"\.huggingface/token",
    r"model_registry_creds",
    r"neptune_api",
    r"mlflow_tracking",
    r"\.comet",
    r"openai_api_key",
    r"anthropic_api_key",
    r"\.kaggle/",
]

COMPILED_PATTERNS = [re.compile(p, re.IGNORECASE) for p in SENSITIVE_PATTERNS]


def is_sensitive(file_path: str) -> bool:
    """Check if a file path matches any sensitive pattern."""
    path_str = str(file_path)
    return any(pattern.search(path_str) for pattern in COMPILED_PATTERNS)


def get_file_path_from_input(tool_input: dict) -> str | None:
    """Extract file path from tool input."""
    # Different tools use different parameter names
    for key in ["file_path", "path", "file"]:
        if key in tool_input:
            return tool_input[key]
    return None


def main() -> int:
    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # Allow on parse error (fail open)

    tool_name = data.get("tool_name", "")

    # Only check file operations
    if tool_name not in ("Read", "Write", "Edit"):
        return 0

    tool_input = data.get("tool_input", {})
    file_path = get_file_path_from_input(tool_input)

    if not file_path:
        return 0  # No file path found, allow

    if is_sensitive(file_path):
        print(
            f"BLOCKED: Access to sensitive file '{file_path}' is not allowed. "
            f"This file matches a protected pattern for security.",
            file=sys.stderr
        )
        return 2  # Block

    return 0  # Allow


if __name__ == "__main__":
    sys.exit(main())
