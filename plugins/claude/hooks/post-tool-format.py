#!/usr/bin/env python3
# === METADATA ===
# NAME: post-tool-format
# TYPE: claude-hook
# PLUGIN: claude
# DESCRIPTION: Auto-formats Python files with Ruff after Write/Edit
# CONFIGURABLE: CLAUDE_HOOK_RUFF_FORMAT
# ================
"""PostToolUse hook to auto-format Python files after Write/Edit.

Runs Ruff format and check --fix on Python files after they're modified.
Only processes .py files to avoid unnecessary processing.

Exit codes:
- 0: Success (or non-Python file, skipped)
- Non-zero: Formatting failed (non-blocking)
"""

import json
import subprocess
import sys
from pathlib import Path


def get_file_path_from_input(tool_input: dict) -> str | None:
    """Extract file path from tool input."""
    for key in ["file_path", "path", "file"]:
        if key in tool_input:
            return tool_input[key]
    return None


def format_python_file(file_path: str) -> bool:
    """Run Ruff format and check --fix on a Python file."""
    try:
        # Run ruff format
        subprocess.run(
            ["ruff", "format", file_path],
            capture_output=True,
            timeout=30,
        )

        # Run ruff check with auto-fix
        subprocess.run(
            ["ruff", "check", "--fix", file_path],
            capture_output=True,
            timeout=30,
        )

        return True
    except FileNotFoundError:
        # Ruff not installed, skip silently
        return True
    except subprocess.TimeoutExpired:
        print("Ruff formatting timed out", file=sys.stderr)
        return False
    except Exception as e:
        print(f"Ruff formatting error: {e}", file=sys.stderr)
        return False


def is_ruff_enabled() -> bool:
    """Check CLAUDE_HOOK_RUFF_FORMAT in config files. Default: true."""
    import os

    config_paths = [
        Path(os.environ.get("CLAUDE_PROJECT_DIR", ""))
        / ".claude"
        / "claude-hooks.conf",
        Path.home() / ".claude" / "claude-hooks.conf",
    ]
    for config_path in config_paths:
        if config_path.is_file():
            for line in config_path.read_text().splitlines():
                line = line.strip()
                if line.startswith("CLAUDE_HOOK_RUFF_FORMAT="):
                    value = line.split("=", 1)[1].strip().strip("\"'")
                    return value.lower() != "false"
    return True


def main() -> int:
    if not is_ruff_enabled():
        return 0

    try:
        data = json.load(sys.stdin)
    except json.JSONDecodeError:
        return 0  # Skip on parse error

    tool_name = data.get("tool_name", "")

    # Only process Write/Edit operations
    if tool_name not in ("Write", "Edit"):
        return 0

    tool_input = data.get("tool_input", {})
    file_path = get_file_path_from_input(tool_input)

    if not file_path:
        return 0

    # Only format Python files
    if not file_path.endswith(".py"):
        return 0

    # Check file exists (it should after Write/Edit)
    if not Path(file_path).exists():
        return 0

    format_python_file(file_path)
    return 0  # Always return 0 (non-blocking hook)


if __name__ == "__main__":
    sys.exit(main())
