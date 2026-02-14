"""Functional tests for vscode plugin.

Tests VS Code configuration files are valid.
Tests are conditional - only run if files exist in manifest.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest


def get_vscode_modules(dotconfigs_root: Path) -> dict[str, Path]:
    """Get dict of VS Code modules from manifest."""
    manifest_path = dotconfigs_root / "plugins" / "vscode" / "manifest.json"
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
def vscode_modules(dotconfigs_root: Path) -> dict[str, Path]:
    """Dict of VS Code modules available."""
    return get_vscode_modules(dotconfigs_root)


class TestVSCodeSettings:
    """Tests for VS Code settings files."""

    def test_settings_valid_json(self, vscode_modules):
        """Settings files are valid JSON."""
        if not vscode_modules:
            pytest.skip("No VS Code modules in manifest")

        for mod_name, file_path in vscode_modules.items():
            if file_path.name.endswith(".json"):
                content = file_path.read_text()
                # Should parse without error
                data = json.loads(content)
                assert isinstance(data, dict)

    def test_settings_exist(self, vscode_modules):
        """All VS Code files in manifest exist."""
        if not vscode_modules:
            pytest.skip("No VS Code modules in manifest")

        for mod_name, file_path in vscode_modules.items():
            assert file_path.exists(), f"{mod_name} file not found: {file_path}"
            assert file_path.is_file()
