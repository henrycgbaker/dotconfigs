"""Functional tests for shell plugin.

Tests shell configuration files can be sourced without errors.
Tests are conditional - only run if files exist in manifest.
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

    # Check global section
    if "global" in manifest:
        for mod_name, mod_config in manifest["global"].items():
            source = dotconfigs_root / mod_config["source"]
            if source.exists():
                modules[mod_name] = source

    return modules


@pytest.fixture(scope="session")
def shell_modules(dotconfigs_root: Path) -> dict[str, Path]:
    """Dict of shell modules available."""
    return get_shell_modules(dotconfigs_root)


class TestShellFiles:
    """Tests for shell configuration files."""

    def test_files_source_without_error(self, shell_modules):
        """Shell files source without syntax errors."""
        requires_cmd("zsh")
        if not shell_modules:
            pytest.skip("No shell modules in manifest")

        for mod_name, file_path in shell_modules.items():
            # Use zsh -n for syntax check (doesn't execute, just parses)
            result = subprocess.run(
                ["zsh", "-n", str(file_path)],
                capture_output=True,
                text=True,
            )

            # Syntax check should pass
            assert (
                result.returncode == 0
            ), f"Syntax error in {mod_name}: {result.stderr}"

    def test_files_exist(self, shell_modules):
        """All shell files in manifest exist."""
        if not shell_modules:
            pytest.skip("No shell modules in manifest")

        for mod_name, file_path in shell_modules.items():
            assert file_path.exists(), f"{mod_name} file not found: {file_path}"
            assert file_path.is_file()
