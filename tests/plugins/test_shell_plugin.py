"""Functional tests for shell plugin.

Tests shell configuration files can be sourced without errors.
Tests are conditional - only run if files exist in manifest.
The shell files are shell-agnostic (bash + zsh), so they must parse cleanly
under whichever of the two shells is available.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from tests.conftest import requires_cmd


def get_shell_modules(dotconfigs_root: Path) -> dict[str, Path]:
    """Get dict of shell modules from manifest."""
    manifest_path = dotconfigs_root / "plugins" / "shell" / "manifest.json"
    if not manifest_path.exists():
        return {}

    manifest = json.loads(manifest_path.read_text())
    modules = {}
    for entries in manifest.values():
        for name, e in entries.items():
            source = dotconfigs_root / e["source"]
            if source.exists():
                modules[name] = source
    return modules


@pytest.fixture(scope="session")
def shell_modules(dotconfigs_root: Path) -> dict[str, Path]:
    """Dict of shell modules available."""
    return get_shell_modules(dotconfigs_root)


class TestShellFiles:
    """Tests for shell configuration files."""

    @pytest.mark.parametrize("shell", ["zsh", "bash"])
    def test_files_parse_without_error(self, shell_modules, shell):
        """Shell files parse without syntax errors in both bash and zsh."""
        requires_cmd(shell)
        if not shell_modules:
            pytest.skip("No shell modules in manifest")

        for mod_name, file_path in shell_modules.items():
            # -n is a syntax check (parses, doesn't execute).
            result = subprocess.run(
                [shell, "-n", str(file_path)],
                capture_output=True,
                text=True,
            )

            assert result.returncode == 0, (
                f"Syntax error in {mod_name} under {shell}: {result.stderr}"
            )

    def test_files_exist(self, shell_modules):
        """All shell files in manifest exist."""
        if not shell_modules:
            pytest.skip("No shell modules in manifest")

        for mod_name, file_path in shell_modules.items():
            assert file_path.exists(), f"{mod_name} file not found: {file_path}"
            assert file_path.is_file()
