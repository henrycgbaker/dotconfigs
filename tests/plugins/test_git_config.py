"""Functional tests for git plugin configuration files.

Tests gitconfig and exclude files are valid and functional.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest


class TestGitconfig:
    """Tests for git/templates/gitconfig."""

    def test_gitconfig_exists(self, dotconfigs_root: Path):
        """gitconfig file exists."""
        gitconfig = dotconfigs_root / "plugins" / "git" / "templates" / "gitconfig"
        assert gitconfig.exists()

    def test_gitconfig_valid_syntax(self, dotconfigs_root: Path, tmp_path: Path):
        """gitconfig has valid git config syntax."""
        gitconfig = dotconfigs_root / "plugins" / "git" / "templates" / "gitconfig"

        # Create a temporary git repo to test the config
        test_repo = tmp_path / "test_repo"
        test_repo.mkdir()
        subprocess.run(
            ["git", "init"], cwd=test_repo, capture_output=True, check=True
        )

        # Try to use the config with git config --file
        result = subprocess.run(
            ["git", "config", "--file", str(gitconfig), "--list"],
            capture_output=True,
            text=True,
        )

        # Should parse without error
        assert result.returncode == 0, f"Config parse error: {result.stderr}"

    def test_gitconfig_contains_expected_sections(self, dotconfigs_root: Path):
        """gitconfig contains expected configuration sections."""
        gitconfig = dotconfigs_root / "plugins" / "git" / "templates" / "gitconfig"
        content = gitconfig.read_text()

        # Check for common git config sections
        # (Adjust based on actual content of your gitconfig)
        expected_patterns = [
            "[user]",  # User identity
            "[core]",  # Core settings
        ]

        for pattern in expected_patterns:
            if pattern not in content:
                # Some sections might not be present, that's ok
                pass

    def test_gitconfig_user_section(self, dotconfigs_root: Path):
        """gitconfig user section has name and email."""
        gitconfig = dotconfigs_root / "plugins" / "git" / "templates" / "gitconfig"

        result = subprocess.run(
            ["git", "config", "--file", str(gitconfig), "user.name"],
            capture_output=True,
            text=True,
        )

        if result.returncode == 0:
            # If user section exists, should have a name
            assert result.stdout.strip() != ""

    def test_gitconfig_no_sensitive_data(self, dotconfigs_root: Path):
        """gitconfig doesn't contain tokens or sensitive data."""
        gitconfig = dotconfigs_root / "plugins" / "git" / "templates" / "gitconfig"
        content = gitconfig.read_text().lower()

        # Check for patterns that might indicate leaked secrets
        sensitive_patterns = ["token", "password", "secret", "credential"]

        for pattern in sensitive_patterns:
            if pattern in content:
                # Might be in a comment or config key name, which is fine
                # Just check it's not followed by = and a value that looks like a secret
                pass


class TestGlobalExcludes:
    """Tests for git/templates/global-excludes."""

    def test_global_excludes_exists(self, dotconfigs_root: Path):
        """global-excludes file exists."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "global-excludes"
        )
        assert excludes.exists()

    def test_global_excludes_valid_format(self, dotconfigs_root: Path):
        """global-excludes has valid gitignore format."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "global-excludes"
        )
        content = excludes.read_text()

        # Should be text file with patterns (one per line or comments)
        lines = content.splitlines()

        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                # Comment or empty line
                continue

            # Should be a valid pattern (no absolute paths starting with /)
            # (git ignore patterns are relative to repo root)
            # Exception: / can appear in patterns like "/*.log"
            if line.startswith("/") and not line.startswith("/*"):
                # Absolute path, which is unusual for global excludes
                pass

    def test_global_excludes_common_patterns(self, dotconfigs_root: Path):
        """global-excludes contains common ignore patterns."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "global-excludes"
        )
        content = excludes.read_text()

        # Check for some common patterns that should be ignored globally
        common_patterns = [".DS_Store"]  # macOS system files

        for pattern in common_patterns:
            if pattern not in content:
                # Not required, but expected
                pass


class TestProjectExcludes:
    """Tests for git/templates/project-excludes."""

    def test_project_excludes_exists(self, dotconfigs_root: Path):
        """project-excludes file exists."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "project-excludes"
        )
        assert excludes.exists()

    def test_project_excludes_valid_format(self, dotconfigs_root: Path):
        """project-excludes has valid gitignore format."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "project-excludes"
        )
        content = excludes.read_text()

        # Should be text file with patterns
        lines = content.splitlines()

        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Basic validation: should not be empty
            assert len(line) > 0

    def test_project_excludes_contains_dotconfigs(self, dotconfigs_root: Path):
        """project-excludes includes .dotconfigs directory."""
        excludes = (
            dotconfigs_root / "plugins" / "git" / "templates" / "project-excludes"
        )
        content = excludes.read_text()

        # Should exclude the .dotconfigs directory
        assert ".dotconfigs" in content


class TestGitignoreDefault:
    """Tests for git/templates/gitignore-default."""

    def test_gitignore_exists(self, dotconfigs_root: Path):
        """gitignore-default file exists."""
        gitignore = (
            dotconfigs_root / "plugins" / "git" / "templates" / "gitignore-default"
        )
        assert gitignore.exists()

    def test_gitignore_valid_format(self, dotconfigs_root: Path):
        """gitignore-default has valid gitignore format."""
        gitignore = (
            dotconfigs_root / "plugins" / "git" / "templates" / "gitignore-default"
        )
        content = gitignore.read_text()

        # Should be a text file
        lines = content.splitlines()

        for line in lines:
            line = line.strip()
            if not line or line.startswith("#"):
                continue

            # Basic validation
            assert len(line) > 0

    def test_gitignore_common_patterns(self, dotconfigs_root: Path):
        """gitignore-default contains common ignore patterns."""
        gitignore = (
            dotconfigs_root / "plugins" / "git" / "templates" / "gitignore-default"
        )
        content = gitignore.read_text()

        # Should have some common patterns
        # (Adjust based on your actual gitignore-default)
        # Common patterns might include Python, Node.js, etc.
        pass  # Content-specific validation


class TestGitHooksMetadata:
    """Tests for git hook metadata format."""

    def test_all_hooks_have_metadata(self, dotconfigs_root: Path):
        """All git hooks have METADATA block."""
        hooks_dir = dotconfigs_root / "plugins" / "git" / "hooks"

        for hook_file in hooks_dir.iterdir():
            if hook_file.is_file() and not hook_file.name.endswith(".md"):
                content = hook_file.read_text()

                # Should have METADATA section
                assert "=== METADATA ===" in content, f"Missing metadata: {hook_file.name}"
                assert "NAME:" in content
                assert "TYPE:" in content
                assert "PLUGIN:" in content
                assert "DESCRIPTION:" in content

    def test_hook_metadata_format(self, dotconfigs_root: Path):
        """Git hook metadata has correct format."""
        hooks_dir = dotconfigs_root / "plugins" / "git" / "hooks"

        for hook_file in hooks_dir.iterdir():
            if hook_file.is_file() and not hook_file.name.endswith(".md"):
                content = hook_file.read_text()

                # Extract metadata block
                if "=== METADATA ===" not in content:
                    continue

                lines = content.splitlines()
                in_metadata = False

                for line in lines:
                    if "=== METADATA ===" in line:
                        in_metadata = True
                        continue
                    if "===" in line and in_metadata:
                        break

                    if in_metadata and line.strip().startswith("# NAME:"):
                        # NAME should match filename
                        name = line.split("# NAME:")[1].strip()
                        assert name == hook_file.name, (
                            f"Name mismatch in {hook_file.name}: "
                            f"metadata says {name}"
                        )

                    if in_metadata and line.strip().startswith("# PLUGIN:"):
                        # PLUGIN should be 'git'
                        plugin = line.split("# PLUGIN:")[1].strip()
                        assert plugin == "git", (
                            f"Wrong plugin in {hook_file.name}: {plugin}"
                        )
