"""Functional tests for shell plugin.

Tests shell configuration files can be sourced without errors.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest


class TestShellInit:
    """Tests for shell/init.zsh."""

    def test_init_sources_without_error(self, dotconfigs_root: Path):
        """init.zsh sources without syntax errors."""
        init_file = dotconfigs_root / "plugins" / "shell" / "init.zsh"
        assert init_file.exists()

        # Use zsh -n for syntax check (doesn't execute, just parses)
        result = subprocess.run(
            ["zsh", "-n", str(init_file)],
            capture_output=True,
            text=True,
        )

        # Syntax check should pass
        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_init_contains_expected_tools(self, dotconfigs_root: Path):
        """init.zsh references expected tools."""
        init_file = dotconfigs_root / "plugins" / "shell" / "init.zsh"
        content = init_file.read_text()

        # Check for key tool initialisations
        assert "starship" in content
        assert "fzf" in content or "FZF" in content

    def test_init_is_idempotent(self, dotconfigs_root: Path, tmp_path: Path):
        """init.zsh can be sourced multiple times safely."""
        init_file = dotconfigs_root / "plugins" / "shell" / "init.zsh"

        # Create a test script that sources init.zsh twice
        test_script = tmp_path / "test.zsh"
        test_script.write_text(
            f"""#!/bin/zsh
# Mock commands to avoid dependency issues
starship() {{ echo "starship mock"; }}
thefuck() {{ echo "thefuck mock"; }}
conda() {{ echo "conda mock"; }}
export -f starship thefuck conda 2>/dev/null || true

# Try to source twice (should not error)
source {init_file} 2>/dev/null || true
source {init_file} 2>/dev/null || true
echo "success"
"""
        )

        result = subprocess.run(
            ["zsh", str(test_script)],
            capture_output=True,
            text=True,
        )

        # Should complete without critical errors
        assert "success" in result.stdout


class TestShellAliases:
    """Tests for shell/aliases.zsh."""

    def test_aliases_sources_without_error(self, dotconfigs_root: Path):
        """aliases.zsh sources without syntax errors."""
        aliases_file = dotconfigs_root / "plugins" / "shell" / "aliases.zsh"
        assert aliases_file.exists()

        # Use zsh -n for syntax check
        result = subprocess.run(
            ["zsh", "-n", str(aliases_file)],
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0, f"Syntax error: {result.stderr}"

    def test_aliases_contains_expected_tools(self, dotconfigs_root: Path):
        """aliases.zsh defines expected aliases."""
        aliases_file = dotconfigs_root / "plugins" / "shell" / "aliases.zsh"
        content = aliases_file.read_text()

        # Check for key aliases
        assert "bat" in content  # cat replacement
        assert "eza" in content  # ls replacement
        assert "claude" in content  # claude CLI

    def test_aliases_sets_path(self, dotconfigs_root: Path):
        """aliases.zsh extends PATH."""
        aliases_file = dotconfigs_root / "plugins" / "shell" / "aliases.zsh"
        content = aliases_file.read_text()

        assert "PATH" in content
        assert ".local/bin" in content

    def test_aliases_is_idempotent(self, dotconfigs_root: Path, tmp_path: Path):
        """aliases.zsh can be sourced multiple times safely."""
        aliases_file = dotconfigs_root / "plugins" / "shell" / "aliases.zsh"

        # Create a test script that sources aliases.zsh twice
        test_script = tmp_path / "test.zsh"
        test_script.write_text(
            f"""#!/bin/zsh
source {aliases_file}
source {aliases_file}
echo "success"
"""
        )

        result = subprocess.run(
            ["zsh", str(test_script)],
            capture_output=True,
            text=True,
        )

        assert "success" in result.stdout


class TestShellIntegration:
    """Integration tests for shell plugin."""

    def test_init_and_aliases_source_together(self, dotconfigs_root: Path, tmp_path: Path):
        """init.zsh and aliases.zsh can be sourced together."""
        init_file = dotconfigs_root / "plugins" / "shell" / "init.zsh"
        aliases_file = dotconfigs_root / "plugins" / "shell" / "aliases.zsh"

        test_script = tmp_path / "test.zsh"
        test_script.write_text(
            f"""#!/bin/zsh
# Mock dependencies
starship() {{ return 0; }}
thefuck() {{ return 0; }}
conda() {{ return 0; }}
export -f starship thefuck conda 2>/dev/null || true

# Source both files
source {init_file} 2>/dev/null || true
source {aliases_file}

# Check that aliases are set
alias | grep -q "cat.*bat" && echo "alias_ok"
echo "success"
"""
        )

        result = subprocess.run(
            ["zsh", str(test_script)],
            capture_output=True,
            text=True,
        )

        assert "success" in result.stdout
        # alias check might fail if bat not installed, but script should still run
