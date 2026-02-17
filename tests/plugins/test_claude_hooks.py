"""Functional tests for claude plugin hooks.

Tests the actual behaviour of Claude hooks, not just deployment.
Tests are conditional - only run if hooks exist in manifest.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from tests.conftest import requires_cmd


def get_available_claude_hooks(dotconfigs_root: Path) -> set[str]:
    """Get set of hooks available in claude plugin manifest."""
    manifest_path = dotconfigs_root / "plugins" / "claude" / "manifest.json"
    if not manifest_path.exists():
        return set()

    manifest = json.loads(manifest_path.read_text())
    hooks = set()

    # Check global and project hooks
    for section in ["global", "project"]:
        if section in manifest and "hooks" in manifest[section]:
            include = manifest[section]["hooks"].get("include", [])
            hooks.update(include)

    return hooks


@pytest.fixture(scope="session")
def available_claude_hooks(dotconfigs_root: Path) -> set[str]:
    """Set of hooks available in claude manifest."""
    return get_available_claude_hooks(dotconfigs_root)


@pytest.fixture
def hook_script(dotconfigs_root: Path, available_claude_hooks):
    """Return path to first available Claude hook, or skip if none."""
    if not available_claude_hooks:
        pytest.skip("No Claude hooks in manifest")

    # Return first available hook
    hook_name = list(available_claude_hooks)[0]
    return dotconfigs_root / "plugins" / "claude" / "hooks" / hook_name


def run_hook(hook_script: Path, tool_name: str, tool_input: dict) -> tuple[int, str]:
    """Run the Claude hook with given tool call data."""
    requires_cmd("bash")
    stdin_data = json.dumps({"tool_name": tool_name, "tool_input": tool_input})

    result = subprocess.run(
        ["bash", str(hook_script)],
        input=stdin_data,
        capture_output=True,
        text=True,
    )

    return result.returncode, result.stdout


def parse_hook_output(output: str) -> dict | None:
    """Parse hook JSON output, return None if empty."""
    if not output.strip():
        return None
    try:
        return json.loads(output)
    except json.JSONDecodeError:
        return None


# ---------------------------------------------------------------------------
# Generic hook tests
# ---------------------------------------------------------------------------


class TestClaudeHooks:
    """Generic tests for Claude hooks."""

    def test_hooks_exist(self, dotconfigs_root: Path, available_claude_hooks):
        """All hooks listed in manifest actually exist as files."""
        if not available_claude_hooks:
            pytest.skip("No Claude hooks in manifest")

        hooks_dir = dotconfigs_root / "plugins" / "claude" / "hooks"

        for hook_name in available_claude_hooks:
            hook_file = hooks_dir / hook_name
            assert hook_file.exists(), f"Hook {hook_name} in manifest but not found"
            assert hook_file.is_file()

    def test_hooks_executable(self, dotconfigs_root: Path, available_claude_hooks):
        """All hook files have shebang."""
        if not available_claude_hooks:
            pytest.skip("No Claude hooks in manifest")

        hooks_dir = dotconfigs_root / "plugins" / "claude" / "hooks"

        for hook_name in available_claude_hooks:
            hook_file = hooks_dir / hook_name
            if hook_file.exists():
                content = hook_file.read_text()
                assert content.startswith(
                    "#!"
                ), f"Hook {hook_name} should start with shebang"

    def test_hook_accepts_safe_commands(self, hook_script):
        """Hook allows safe commands."""
        returncode, output = run_hook(hook_script, "Bash", {"command": "ls -la"})
        assert returncode == 0
        data = parse_hook_output(output)
        # Should allow (no output or no deny decision)
        if data:
            assert (
                data.get("hookSpecificOutput", {}).get("permissionDecision") != "deny"
            )

    def test_hook_accepts_safe_writes(self, hook_script):
        """Hook allows writes to normal files."""
        returncode, output = run_hook(
            hook_script,
            "Write",
            {"file_path": "/tmp/test.txt", "content": "data"},
        )
        assert returncode == 0
        data = parse_hook_output(output)
        if data:
            assert (
                data.get("hookSpecificOutput", {}).get("permissionDecision") != "deny"
            )
