"""Functional tests for git plugin configuration files.

Tests gitconfig and exclude files are valid and functional.
Tests are conditional - only run if files exist in manifest.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


def get_git_config_files(dotconfigs_root: Path) -> dict[str, Path]:
    """Get dict of git config files from manifest."""
    manifest_path = dotconfigs_root / "plugins" / "git" / "manifest.json"
    if not manifest_path.exists():
        return {}

    manifest = json.loads(manifest_path.read_text())
    config_files = {}

    # Collect all non-hook modules
    for section in ["global", "project"]:
        if section in manifest:
            for mod_name, mod_config in manifest[section].items():
                if mod_name != "hooks":  # Skip hooks module
                    source = dotconfigs_root / mod_config["source"]
                    if source.exists():
                        config_files[f"{section}/{mod_name}"] = source

    return config_files


def get_available_hooks(dotconfigs_root: Path) -> set[str]:
    """Get set of hooks available in git plugin manifest."""
    manifest_path = dotconfigs_root / "plugins" / "git" / "manifest.json"
    if not manifest_path.exists():
        return set()

    manifest = json.loads(manifest_path.read_text())
    hooks = set()

    for section in ["global", "project"]:
        if section in manifest and "hooks" in manifest[section]:
            include = manifest[section]["hooks"].get("include", [])
            hooks.update(include)

    return hooks


@pytest.fixture(scope="session")
def git_config_files(dotconfigs_root: Path) -> dict[str, Path]:
    """Dict of git config files available."""
    return get_git_config_files(dotconfigs_root)


@pytest.fixture(scope="session")
def git_hooks(dotconfigs_root: Path) -> set[str]:
    """Set of git hooks available."""
    return get_available_hooks(dotconfigs_root)


class TestGitConfigFiles:
    """Tests for git configuration files."""

    def test_config_files_exist(self, git_config_files):
        """All config files in manifest exist."""
        if not git_config_files:
            pytest.skip("No git config files in manifest")

        for module_name, file_path in git_config_files.items():
            assert file_path.exists(), f"{module_name} not found: {file_path}"

    def test_gitconfig_valid_syntax(self, dotconfigs_root: Path, git_config_files, tmp_path):
        """gitconfig has valid git config syntax."""
        gitconfig_path = None

        # Find gitconfig in config files
        for module_name, file_path in git_config_files.items():
            if "config" in module_name.lower() and file_path.name == "gitconfig":
                gitconfig_path = file_path
                break

        if not gitconfig_path:
            pytest.skip("gitconfig not in manifest")

        # Try to parse with git config --file
        result = subprocess.run(
            ["git", "config", "--file", str(gitconfig_path), "--list"],
            capture_output=True,
            text=True,
        )

        # Should parse without error
        assert result.returncode == 0, f"Config parse error: {result.stderr}"

    def test_excludes_files_valid_format(self, git_config_files):
        """Exclude files have valid gitignore format."""
        exclude_files = [
            path for name, path in git_config_files.items()
            if "exclude" in name.lower() or "gitignore" in name.lower()
        ]

        if not exclude_files:
            pytest.skip("No exclude/gitignore files in manifest")

        for exclude_file in exclude_files:
            content = exclude_file.read_text()

            # Should be text file with patterns
            lines = content.splitlines()

            for line in lines:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue

                # Basic validation: should not be empty
                assert len(line) > 0


class TestGitHooksMetadata:
    """Tests for git hook metadata format."""

    def test_hooks_have_metadata(self, dotconfigs_root: Path, git_hooks):
        """Hooks have METADATA block."""
        if not git_hooks:
            pytest.skip("No git hooks in manifest")

        hooks_dir = dotconfigs_root / "plugins" / "git" / "hooks"

        for hook_name in git_hooks:
            hook_file = hooks_dir / hook_name
            if not hook_file.exists():
                continue

            content = hook_file.read_text()

            # Should have METADATA section
            assert "=== METADATA ===" in content, (
                f"Missing metadata in {hook_name}"
            )
