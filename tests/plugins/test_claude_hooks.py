"""Functional tests for claude plugin hooks.

Tests the actual behaviour of Claude hooks, not just deployment.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


@pytest.fixture
def hook_script(dotconfigs_root: Path) -> Path:
    """Return path to block-destructive hook."""
    return dotconfigs_root / "plugins" / "claude" / "hooks" / "block-destructive.sh"


def run_hook(hook_script: Path, tool_name: str, tool_input: dict) -> tuple[int, str]:
    """Run the Claude hook with given tool call data."""
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
# Destructive Command Guard
# ---------------------------------------------------------------------------


class TestDestructiveCommandGuard:
    """Tests for destructive command blocking in Bash tool."""

    def test_blocks_rm_rf_root(self, hook_script):
        """Hook blocks rm -rf /."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "rm -rf /"},
        )

        assert returncode == 0  # Hook exits 0 even when denying
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "rm -rf /" in data["hookSpecificOutput"]["permissionDecisionReason"]

    def test_blocks_rm_rf_home(self, hook_script):
        """Hook blocks rm -rf ~."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "rm -rf ~/"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "rm -rf ~" in data["hookSpecificOutput"]["permissionDecisionReason"]

    def test_allows_normal_rm(self, hook_script):
        """Hook allows normal rm commands."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "rm -rf ./build"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        # Should be None (implicit allow) or empty
        assert data is None or data == {}

    def test_blocks_git_push_force(self, hook_script):
        """Hook blocks git push --force."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "git push --force"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "force" in data["hookSpecificOutput"]["permissionDecisionReason"].lower()

    def test_allows_git_push_force_with_lease(self, hook_script):
        """Hook allows git push --force-with-lease."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "git push --force-with-lease"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is None or data == {}

    def test_blocks_git_reset_hard(self, hook_script):
        """Hook blocks git reset --hard."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "git reset --hard HEAD~1"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "reset --hard" in data["hookSpecificOutput"]["permissionDecisionReason"]

    def test_blocks_git_clean_fd(self, hook_script):
        """Hook blocks git clean -fd."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "git clean -fd"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "clean" in data["hookSpecificOutput"]["permissionDecisionReason"].lower()

    def test_blocks_drop_table(self, hook_script):
        """Hook blocks DROP TABLE commands."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": 'psql -c "DROP TABLE users"'},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "DROP" in data["hookSpecificOutput"]["permissionDecisionReason"]

    def test_blocks_drop_database(self, hook_script):
        """Hook blocks DROP DATABASE commands."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": 'mysql -e "DROP DATABASE prod"'},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "DROP" in data["hookSpecificOutput"]["permissionDecisionReason"]

    def test_blocks_chmod_777(self, hook_script):
        """Hook blocks chmod -R 777."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "chmod -R 777 /var/www"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "chmod" in data["hookSpecificOutput"]["permissionDecisionReason"].lower()

    def test_allows_safe_commands(self, hook_script):
        """Hook allows safe bash commands."""
        safe_commands = [
            "ls -la",
            "git status",
            "npm install",
            "pytest tests/",
            "echo hello",
        ]

        for cmd in safe_commands:
            returncode, output = run_hook(hook_script, "Bash", {"command": cmd})
            assert returncode == 0
            data = parse_hook_output(output)
            assert data is None or data == {}, f"Safe command blocked: {cmd}"


# ---------------------------------------------------------------------------
# File Protection
# ---------------------------------------------------------------------------


class TestFileProtection:
    """Tests for file protection in Write/Edit tools."""

    def test_blocks_pem_file_write(self, hook_script):
        """Hook blocks writing to .pem files."""
        returncode, output = run_hook(
            hook_script,
            "Write",
            {"file_path": "/path/to/private.pem", "content": "data"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert "pem" in data["hookSpecificOutput"]["permissionDecisionReason"].lower()

    def test_blocks_credentials_file_write(self, hook_script):
        """Hook blocks writing to files with 'credentials' in name."""
        returncode, output = run_hook(
            hook_script,
            "Write",
            {"file_path": "/app/credentials.json", "content": "{}"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert (
            "credentials"
            in data["hookSpecificOutput"]["permissionDecisionReason"].lower()
        )

    def test_blocks_env_production_write(self, hook_script):
        """Hook blocks writing to .env.production."""
        returncode, output = run_hook(
            hook_script,
            "Write",
            {"file_path": "/app/.env.production", "content": "KEY=value"},
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
        assert (
            "production"
            in data["hookSpecificOutput"]["permissionDecisionReason"].lower()
        )

    def test_blocks_ssh_key_write(self, hook_script):
        """Hook blocks writing to SSH private keys."""
        for key_name in ["id_rsa", "id_ed25519"]:
            returncode, output = run_hook(
                hook_script,
                "Write",
                {"file_path": f"/home/user/.ssh/{key_name}", "content": "KEY DATA"},
            )

            assert returncode == 0
            data = parse_hook_output(output)
            assert data is not None
            assert data["hookSpecificOutput"]["permissionDecision"] == "deny"
            assert (
                "SSH" in data["hookSpecificOutput"]["permissionDecisionReason"]
                or "key" in data["hookSpecificOutput"]["permissionDecisionReason"].lower()
            )

    def test_blocks_pem_file_edit(self, hook_script):
        """Hook blocks editing .pem files."""
        returncode, output = run_hook(
            hook_script,
            "Edit",
            {
                "file_path": "/certs/server.pem",
                "old_string": "old",
                "new_string": "new",
            },
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"

    def test_allows_normal_file_writes(self, hook_script):
        """Hook allows writing to normal files."""
        safe_writes = [
            "/app/src/main.py",
            "/docs/README.md",
            "/config/settings.json",
            "/tmp/output.txt",
        ]

        for path in safe_writes:
            returncode, output = run_hook(
                hook_script,
                "Write",
                {"file_path": path, "content": "content"},
            )
            assert returncode == 0
            data = parse_hook_output(output)
            assert data is None or data == {}, f"Safe write blocked: {path}"

    def test_allows_env_development_write(self, hook_script):
        """Hook allows writing to .env and .env.development."""
        for env_file in [".env", ".env.development", ".env.local"]:
            returncode, output = run_hook(
                hook_script,
                "Write",
                {"file_path": env_file, "content": "KEY=value"},
            )
            assert returncode == 0
            data = parse_hook_output(output)
            assert data is None or data == {}, f".env file blocked: {env_file}"


# ---------------------------------------------------------------------------
# Tool Type Handling
# ---------------------------------------------------------------------------


class TestToolTypeHandling:
    """Tests that hook correctly handles different tool types."""

    def test_ignores_non_bash_tools(self, hook_script):
        """Hook ignores non-Bash tools for command checking."""
        returncode, output = run_hook(
            hook_script,
            "Read",
            {"file_path": "rm -rf /"},  # Would be dangerous if parsed as command
        )

        assert returncode == 0
        data = parse_hook_output(output)
        assert data is None or data == {}

    def test_ignores_non_write_edit_tools(self, hook_script):
        """Hook ignores non-Write/Edit tools for file protection."""
        returncode, output = run_hook(
            hook_script,
            "Bash",
            {"command": "cat private.pem"},  # Reading, not writing
        )

        assert returncode == 0
        data = parse_hook_output(output)
        # Should not trigger file protection (only destructive command check applies)
        assert data is None or data == {}


# ---------------------------------------------------------------------------
# Config Loading
# ---------------------------------------------------------------------------


class TestConfigLoading:
    """Tests for config loading and environment variables."""

    def test_respects_env_var_disable(self, hook_script, tmp_path):
        """Hook respects CLAUDE_HOOK_DESTRUCTIVE_GUARD=false."""
        env = {"CLAUDE_HOOK_DESTRUCTIVE_GUARD": "false"}

        stdin_data = json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}
        )

        result = subprocess.run(
            ["bash", str(hook_script)],
            input=stdin_data,
            capture_output=True,
            text=True,
            env={**subprocess.os.environ, **env},
        )

        assert result.returncode == 0
        data = parse_hook_output(result.stdout)
        # Should allow when guard disabled
        assert data is None or data == {}

    def test_respects_file_protection_disable(self, hook_script):
        """Hook respects CLAUDE_HOOK_FILE_PROTECTION=false."""
        env = {"CLAUDE_HOOK_FILE_PROTECTION": "false"}

        stdin_data = json.dumps(
            {
                "tool_name": "Write",
                "tool_input": {"file_path": "/app/private.pem", "content": "data"},
            }
        )

        result = subprocess.run(
            ["bash", str(hook_script)],
            input=stdin_data,
            capture_output=True,
            text=True,
            env={**subprocess.os.environ, **env},
        )

        assert result.returncode == 0
        data = parse_hook_output(result.stdout)
        # Should allow when protection disabled
        assert data is None or data == {}

    def test_handles_missing_jq_gracefully(self, hook_script, tmp_path):
        """Hook exits gracefully when jq is not available."""
        # Create a wrapper script that makes jq unavailable
        wrapper = tmp_path / "hook_wrapper.sh"
        wrapper.write_text(
            f"""#!/bin/bash
command() {{
    if [[ "$1" == "-v" ]] && [[ "$2" == "jq" ]]; then
        return 1
    fi
    builtin command "$@"
}}
export -f command
source {hook_script}
"""
        )
        wrapper.chmod(0o755)

        stdin_data = json.dumps(
            {"tool_name": "Bash", "tool_input": {"command": "rm -rf /"}}
        )

        result = subprocess.run(
            ["bash", str(wrapper)],
            input=stdin_data,
            capture_output=True,
            text=True,
        )

        # Should exit 0 silently when jq missing
        assert result.returncode == 0
        assert result.stdout.strip() == ""
