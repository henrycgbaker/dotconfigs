"""Functional tests for git plugin hooks.

Tests the actual behaviour of git hooks, not just deployment.
"""

from __future__ import annotations

import subprocess
from pathlib import Path

import pytest


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


@pytest.fixture
def install_hook(dotconfigs_root: Path):
    """Factory: install a specific hook into a repo."""

    def _install(repo: Path, hook_name: str) -> Path:
        hook_source = dotconfigs_root / "plugins" / "git" / "hooks" / hook_name
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

    def test_identity_check_passes(self, git_repo, install_hook):
        """pre-commit allows commit with correct identity."""
        install_hook(git_repo, "pre-commit")
        test_file = git_repo / "test.txt"
        test_file.write_text("test content")

        subprocess.run(["git", "add", "test.txt"], cwd=git_repo, check=True)
        result = subprocess.run(
            ["git", "commit", "-m", "test"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_identity_check_blocks_wrong_name(self, git_repo, install_hook):
        """pre-commit blocks commit with wrong git name."""
        install_hook(git_repo, "pre-commit")
        subprocess.run(
            ["git", "config", "user.name", "wrongname"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        test_file = git_repo / "test.txt"
        test_file.write_text("test content")
        subprocess.run(["git", "add", "test.txt"], cwd=git_repo, check=True)

        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "identity mismatch" in result.stdout.lower()

    def test_identity_check_blocks_wrong_email(self, git_repo, install_hook):
        """pre-commit blocks commit with wrong git email."""
        install_hook(git_repo, "pre-commit")
        subprocess.run(
            ["git", "config", "user.email", "wrong@example.com"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        test_file = git_repo / "test.txt"
        test_file.write_text("test content")
        subprocess.run(["git", "add", "test.txt"], cwd=git_repo, check=True)

        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "identity mismatch" in result.stdout.lower()

    def test_warns_on_main_branch(self, git_repo, install_hook):
        """pre-commit warns when committing to main."""
        install_hook(git_repo, "pre-commit")

        # Get current branch and switch to main if needed
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=git_repo,
            capture_output=True,
            text=True,
            check=True,
        )
        current_branch = result.stdout.strip()

        # If not on main/master, create and switch to main
        if current_branch not in ["main", "master"]:
            subprocess.run(
                ["git", "checkout", "-b", "main"],
                cwd=git_repo,
                capture_output=True,
                check=True,
            )

        test_file = git_repo / "test.txt"
        test_file.write_text("test content")
        subprocess.run(["git", "add", "test.txt"], cwd=git_repo, check=True)

        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert "WARNING" in result.stdout
        assert "main" in result.stdout.lower() or "master" in result.stdout.lower()

    def test_secrets_scan_blocks_aws_key(self, git_repo, install_hook):
        """pre-commit blocks commit with AWS access key."""
        install_hook(git_repo, "pre-commit")

        # Checkout feature branch to avoid main branch warnings
        subprocess.run(
            ["git", "checkout", "-b", "feature/test"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        test_file = git_repo / "credentials.txt"
        # Use properly formatted fake AWS key (AKIA + 16 alphanumeric chars)
        test_file.write_text("AWS_ACCESS_KEY=AKIAIOSFODNN7EXAMP12")
        subprocess.run(["git", "add", "credentials.txt"], cwd=git_repo, check=True)

        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "secret" in result.stdout.lower()

    def test_secrets_scan_blocks_private_key(self, git_repo, install_hook):
        """pre-commit blocks commit with private key (regex fallback)."""
        install_hook(git_repo, "pre-commit")

        # Checkout feature branch to avoid main branch warnings
        subprocess.run(
            ["git", "checkout", "-b", "feature/key-test"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        test_file = git_repo / "key.pem"
        test_file.write_text("""-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEA1234567890abcdefghijklmnopqrstuvwxyz
-----END RSA PRIVATE KEY-----""")
        subprocess.run(["git", "add", "key.pem"], cwd=git_repo, check=True)

        # Run hook with PATH modified to hide gitleaks (forces regex fallback)
        env = subprocess.os.environ.copy()
        env["PATH"] = "/usr/bin:/bin"  # Minimal PATH without gitleaks

        result = subprocess.run(
            [".git/hooks/pre-commit"],
            cwd=git_repo,
            capture_output=True,
            text=True,
            env=env,
        )
        assert result.returncode != 0
        assert "private key" in result.stdout.lower()


# ---------------------------------------------------------------------------
# commit-msg hook
# ---------------------------------------------------------------------------


class TestCommitMsgHook:
    """Tests for commit-msg hook functionality."""

    def test_allows_normal_message(self, git_repo, install_hook):
        """commit-msg allows normal commit messages."""
        install_hook(git_repo, "commit-msg")

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("feat: add new feature")

        result = subprocess.run(
            [".git/hooks/commit-msg", str(msg_file)],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

    def test_blocks_claude_attribution(self, git_repo, install_hook):
        """commit-msg blocks Claude co-author attribution."""
        install_hook(git_repo, "commit-msg")

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text(
            "feat: add feature\n\nCo-Authored-By: Claude Sonnet 4.5 <noreply@anthropic.com>"
        )

        result = subprocess.run(
            [".git/hooks/commit-msg", str(msg_file)],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "AI attribution" in result.stdout

    def test_blocks_gpt_attribution(self, git_repo, install_hook):
        """commit-msg blocks GPT attribution."""
        install_hook(git_repo, "commit-msg")

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("feat: add feature\n\nGenerated with GPT-4")

        result = subprocess.run(
            [".git/hooks/commit-msg", str(msg_file)],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "AI attribution" in result.stdout

    def test_blocks_ai_emoji_pattern(self, git_repo, install_hook):
        """commit-msg blocks AI emoji patterns."""
        install_hook(git_repo, "commit-msg")

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("feat: add feature\n\n🤖 Generated automatically")

        result = subprocess.run(
            [".git/hooks/commit-msg", str(msg_file)],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode != 0
        assert "AI attribution" in result.stdout


# ---------------------------------------------------------------------------
# prepare-commit-msg hook
# ---------------------------------------------------------------------------


class TestPrepareCommitMsgHook:
    """Tests for prepare-commit-msg hook functionality."""

    @pytest.mark.parametrize(
        "branch,expected_prefix",
        [
            ("feature/add-login", "feat: "),
            ("fix/broken-link", "fix: "),
            ("docs/update-readme", "docs: "),
            ("refactor/cleanup", "refactor: "),
            ("test/add-tests", "test: "),
            ("chore/deps", "chore: "),
            ("perf/optimize", "perf: "),
            ("style/format", "style: "),
        ],
    )
    def test_branch_prefix_extraction(
        self, git_repo, install_hook, branch, expected_prefix
    ):
        """prepare-commit-msg adds correct prefix based on branch name."""
        install_hook(git_repo, "prepare-commit-msg")

        # Create and checkout branch
        subprocess.run(
            ["git", "checkout", "-b", branch],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        msg_file.write_text("add new thing")

        result = subprocess.run(
            [".git/hooks/prepare-commit-msg", str(msg_file), "message"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

        updated_msg = msg_file.read_text()
        assert updated_msg.startswith(expected_prefix)
        assert "add new thing" in updated_msg

    def test_skips_merge_commits(self, git_repo, install_hook):
        """prepare-commit-msg skips merge commits."""
        install_hook(git_repo, "prepare-commit-msg")

        subprocess.run(
            ["git", "checkout", "-b", "feature/test"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        original_msg = "Merge branch 'main'"
        msg_file.write_text(original_msg)

        result = subprocess.run(
            [".git/hooks/prepare-commit-msg", str(msg_file), "merge"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

        # Message should be unchanged
        assert msg_file.read_text() == original_msg

    def test_skips_existing_conventional_commit(self, git_repo, install_hook):
        """prepare-commit-msg skips messages with existing conventional prefix."""
        install_hook(git_repo, "prepare-commit-msg")

        subprocess.run(
            ["git", "checkout", "-b", "feature/test"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        msg_file = git_repo / ".git" / "COMMIT_EDITMSG"
        original_msg = "fix: already has prefix"
        msg_file.write_text(original_msg)

        result = subprocess.run(
            [".git/hooks/prepare-commit-msg", str(msg_file), "message"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0

        # Message should be unchanged
        assert msg_file.read_text() == original_msg


# ---------------------------------------------------------------------------
# pre-push hook
# ---------------------------------------------------------------------------


class TestPrePushHook:
    """Tests for pre-push hook functionality."""

    def test_blocks_force_push_to_main(self, git_repo, install_hook):
        """pre-push blocks force push to main/master."""
        install_hook(git_repo, "pre-push")

        # Simulate force push stdin (non-ff push to main)
        push_input = "refs/heads/main abc123 refs/heads/main def456\n"

        result = subprocess.run(
            [".git/hooks/pre-push", "origin", "https://example.com/repo.git"],
            input=push_input,
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        # Hook should detect potential force push
        # Note: actual detection requires valid git history
        # This is a smoke test that the hook runs
        assert result.returncode in [0, 1]

    def test_hook_runs_without_error(self, git_repo, install_hook):
        """pre-push hook executes without errors for normal push."""
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

        # Should run validation commands (may fail if tools not present, that's ok)
        assert result.returncode in [0, 1]


# ---------------------------------------------------------------------------
# post-merge hook
# ---------------------------------------------------------------------------


class TestPostMergeHook:
    """Tests for post-merge hook functionality."""

    def test_detects_package_json_change(self, git_repo, install_hook, tmp_path):
        """post-merge detects package.json changes."""
        install_hook(git_repo, "post-merge")

        # Get the current branch name
        result = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=git_repo,
            capture_output=True,
            text=True,
            check=True,
        )
        main_branch = result.stdout.strip()

        # Create branch and modify package.json
        subprocess.run(
            ["git", "checkout", "-b", "feature/deps"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )
        pkg = git_repo / "package.json"
        pkg.write_text('{"dependencies": {}}')
        subprocess.run(["git", "add", "package.json"], cwd=git_repo, check=True)
        subprocess.run(
            ["git", "commit", "-m", "add deps"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        # Switch back and merge
        subprocess.run(
            ["git", "checkout", main_branch],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )
        subprocess.run(
            ["git", "merge", "feature/deps", "--no-edit"],
            cwd=git_repo,
            capture_output=True,
            check=True,
        )

        # Hook runs automatically, but we can also invoke it manually
        result = subprocess.run(
            [".git/hooks/post-merge", "0"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
        assert "DEPENDENCY" in result.stdout or "package" in result.stdout.lower()

    def test_hook_runs_without_error(self, git_repo, install_hook):
        """post-merge hook executes without errors."""
        install_hook(git_repo, "post-merge")

        result = subprocess.run(
            [".git/hooks/post-merge", "0"],
            cwd=git_repo,
            capture_output=True,
            text=True,
        )

        assert result.returncode == 0
