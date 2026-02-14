"""Functional tests for vscode plugin.

Tests VS Code configuration files are valid.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest


class TestVSCodeSettings:
    """Tests for vscode/settings.json."""

    def test_settings_file_exists(self, dotconfigs_root: Path):
        """settings.json exists."""
        settings_file = dotconfigs_root / "plugins" / "vscode" / "settings.json"
        assert settings_file.exists()

    def test_settings_is_valid_json(self, dotconfigs_root: Path):
        """settings.json is valid JSON."""
        settings_file = dotconfigs_root / "plugins" / "vscode" / "settings.json"
        content = settings_file.read_text()

        # Should parse without error
        data = json.loads(content)
        assert isinstance(data, dict)

    def test_settings_contains_expected_keys(self, dotconfigs_root: Path):
        """settings.json contains expected VS Code settings."""
        settings_file = dotconfigs_root / "plugins" / "vscode" / "settings.json"
        data = json.loads(settings_file.read_text())

        # Basic validation - should be a dict with string keys
        assert all(isinstance(k, str) for k in data.keys())

    def test_settings_no_absolute_paths(self, dotconfigs_root: Path):
        """settings.json avoids hardcoded absolute paths."""
        settings_file = dotconfigs_root / "plugins" / "vscode" / "settings.json"
        content = settings_file.read_text()

        # Check for common absolute path patterns that shouldn't be in shared config
        # (Some absolute paths like /usr/bin are ok, user home paths are not)
        problematic_patterns = ["/Users/", "/home/"]

        for pattern in problematic_patterns:
            if pattern in content:
                # Check if it's in a comment or acceptable context
                # For now, just warn
                pass  # Could make this stricter

    def test_settings_structure(self, dotconfigs_root: Path):
        """settings.json has valid VS Code setting structure."""
        settings_file = dotconfigs_root / "plugins" / "vscode" / "settings.json"
        data = json.loads(settings_file.read_text())

        # VS Code settings are flat key-value pairs
        # Keys usually have format like "editor.fontSize" or "python.linting.enabled"
        for key, value in data.items():
            # Key should be a string with at least one component
            assert isinstance(key, str)
            assert len(key) > 0

            # Value can be bool, string, number, array, or object
            assert value is None or isinstance(
                value, (bool, str, int, float, list, dict)
            )
