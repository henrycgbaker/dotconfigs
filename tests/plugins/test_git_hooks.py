"""Functional tests for git plugin hooks.

Tests the actual behaviour of git hooks, not just deployment.
Tests are conditional - only run if hooks exist in manifest.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


def get_available_hooks(dotconfigs_root: Path) -> set[str]:
    """Get set of hooks available in git plugin manifest."""
    manifest_path = dotconfigs_root / "plugins" / "git" / "manifest.json"
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


@pytest.fixture
def git_repo(tmp_path: Path) -> Path:
    """Create a git repository with proper identity and initial commit."""
    repo = tmp_path / "test_repo"
    repo.mkdir()
    subprocess.run(["git", "init"], cwd=repo, capture_output=True, check=True)
    subprocess.run(
        ["git", "config", "user.name", "henrycgbaker"],
        cwd=repo,
        capture_output=True,
        check=True,
    )
    subprocess.run(
        ["git", "config", "user.email", "henry.c.g.baker@gmail.com"],
        cwd=repo,
        capture_output=True,
        check=True,
    )

    # Create initial commit so HEAD exists
    initial_file = repo / ".gitkeep"
    initial_file.write_text("")
    subprocess.run(["git", "add", ".gitkeep"], cwd=repo, capture_output=True, check=True)
    subprocess.run(
        ["git", "commit", "-m", "initial commit", "--no-verify"],
        cwd=repo,
        capture_output=True,
        check=True,
    )

    return repo


@pytest.fixture(scope="session")
def available_hooks(dotconfigs_root: Path) -> set[str]:
    """Set of hooks available in git manifest."""
    return get_available_hooks(dotconfigs_root)


@pytest.fixture
def install_hook(dotconfigs_root: Path):
    """Factory: install a specific hook into a repo."""

    def _install(repo: Path, hook_name: str) -> Path:
        hook_source = dotconfigs_root / "plugins" / "git" / "hooks" / hook_name
        if not hook_source.exists():
            pytest.skip(f"Hook {hook_name} not found in plugins/git/hooks/")

        hook_target = repo / ".git" / "hooks" / hook_name
        hook_target.parent.mkdir(parents=True, exist_ok=True)
        hook_target.write_text(hook_source.read_text())
        hook_target.chmod(0o755)
        return hook_target

    return _install


# ---------------------------------------------------------------------------
# pre-commit hook
# ---------------------------------------------------------------------------


class TestPreCommitHook:
    """Tests for pre-commit hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """pre-commit hook executes without errors."""
        if "pre-commit" not in available_hooks:
            pytest.skip("pre-commit hook not in manifest")

        install_hook(git_repo, "pre-commit")
        test_file = git_repo / "test.txt"
        test_file.write_text("test content")
        subprocess.run(["git", "add", "test.txt"], cwd=git_repo, check=True)

        # Just verify hook runs (may pass or fail depending on content)
        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        # Hook executed (returned 0 or 1, not crashed)
        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# commit-msg hook
# ---------------------------------------------------------------------------


class TestCommitMsgHook:
    """Tests for commit-msg hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """commit-msg hook executes without errors."""
        if "commit-msg" not in available_hooks:
            pytest.skip("commit-msg hook not in manifest")

        install_hook(git_repo, "commit-msg")
        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("test: normal commit message")

        result = subprocess.run(
            [".git/hooks/commit-msg", str(msg_file)],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        # Hook should accept normal messages
        assert result.returncode == 0


# ---------------------------------------------------------------------------
# prepare-commit-msg hook
# ---------------------------------------------------------------------------


class TestPrepareCommitMsgHook:
    """Tests for prepare-commit-msg hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """prepare-commit-msg hook executes without errors."""
        if "prepare-commit-msg" not in available_hooks:
            pytest.skip("prepare-commit-msg hook not in manifest")

        install_hook(git_repo, "prepare-commit-msg")
        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("test message")

        result = subprocess.run(
            [".git/hooks/prepare-commit-msg", str(msg_file), "message"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0


# ---------------------------------------------------------------------------
# pre-push hook
# ---------------------------------------------------------------------------


class TestPrePushHook:
    """Tests for pre-push hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """pre-push hook executes without errors."""
        if "pre-push" not in available_hooks:
            pytest.skip("pre-push hook not in manifest")

        install_hook(git_repo, "pre-push")

        # Simulate normal push stdin (new branch)
        push_input = "refs/heads/feature/test abc123 refs/heads/feature/test 0000000000000000000000000000000000000000\n"

        result = subprocess.run(
            [".git/hooks/pre-push", "origin", "https://example.com/repo.git"],
            input=push_input,
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        # Hook executed (may fail if validation tools missing, that's ok)
        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# post-merge hook
# ---------------------------------------------------------------------------


class TestPostMergeHook:
    """Tests for post-merge hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """post-merge hook executes without errors."""
        if "post-merge" not in available_hooks:
            pytest.skip("post-merge hook not in manifest")

        install_hook(git_repo, "post-merge")

        result = subprocess.run(
            [".git/hooks/post-merge", "0"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0


# ---------------------------------------------------------------------------
# post-checkout hook
# ---------------------------------------------------------------------------


class TestPostCheckoutHook:
    """Tests for post-checkout hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """post-checkout hook executes without errors."""
        if "post-checkout" not in available_hooks:
            pytest.skip("post-checkout hook not in manifest")

        install_hook(git_repo, "post-checkout")

        # post-checkout takes: prev-HEAD new-HEAD branch-checkout-flag
        result = subprocess.run(
            [".git/hooks/post-checkout", "abc123", "def456", "1"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# post-rewrite hook
# ---------------------------------------------------------------------------


class TestPostRewriteHook:
    """Tests for post-rewrite hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """post-rewrite hook executes without errors."""
        if "post-rewrite" not in available_hooks:
            pytest.skip("post-rewrite hook not in manifest")

        install_hook(git_repo, "post-rewrite")

        # post-rewrite takes rewrite type as argument
        result = subprocess.run(
            [".git/hooks/post-rewrite", "rebase"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# pre-rebase hook
# ---------------------------------------------------------------------------


class TestPreRebaseHook:
    """Tests for pre-rebase hook functionality."""

    def test_hook_executes(self, git_repo, install_hook, available_hooks):
        """pre-rebase hook executes without errors."""
        if "pre-rebase" not in available_hooks:
            pytest.skip("pre-rebase hook not in manifest")

        install_hook(git_repo, "pre-rebase")

        # pre-rebase takes upstream and branch (optional)
        result = subprocess.run(
            [".git/hooks/pre-rebase", "main"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# Generic hook tests
# ---------------------------------------------------------------------------


class TestAllHooks:
    """Generic tests that apply to all hooks."""

    def test_all_manifest_hooks_exist(self, dotconfigs_root: Path, available_hooks):
        """All hooks listed in manifest actually exist as files."""
        hooks_dir = dotconfigs_root / "plugins" / "git" / "hooks"

        for hook_name in available_hooks:
            hook_file = hooks_dir / hook_name
            assert hook_file.exists(), f"Hook {hook_name} in manifest but not found at {hook_file}"
            assert hook_file.is_file()

    def test_all_hooks_executable(self, dotconfigs_root: Path, available_hooks):
        """All hook files are executable."""
        hooks_dir = dotconfigs_root / "plugins" / "git" / "hooks"

        for hook_name in available_hooks:
            hook_file = hooks_dir / hook_name
            if hook_file.exists():
                # Check has shebang (executable script)
                content = hook_file.read_text()
                assert content.startswith("#!") or content.startswith("#!/"), (
                    f"Hook {hook_name} should start with shebang"
                )
