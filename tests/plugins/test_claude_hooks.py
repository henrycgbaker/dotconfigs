"""Functional tests for claude plugin hooks.

Tests the actual behaviour of Claude hooks, not just deployment.
Tests are conditional - only run if hooks exist in manifest.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from tests.conftest import requires_cmd


def get_available_claude_hooks(dotconfigs_root: Path) -> set[str]:
    """Get set of hooks available in claude plugin manifest."""
    manifest_path = dotconfigs_root / "plugins" / "claude" / "manifest.json"
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


@pytest.fixture(scope="session")
def available_claude_hooks(dotconfigs_root: Path) -> set[str]:
    """Set of hooks available in claude manifest."""
    return get_available_claude_hooks(dotconfigs_root)


@pytest.fixture
def hook_script(dotconfigs_root: Path, available_claude_hooks):
    """Return path to first available Claude hook, or skip if none."""
    if not available_claude_hooks:
        pytest.skip("No Claude hooks in manifest")

    # Return first available hook
    hook_name = list(available_claude_hooks)[0]
    return dotconfigs_root / "plugins" / "claude" / "hooks" / hook_name


def run_hook(
    hook_script: Path,
    tool_name: str,
    tool_input: dict,
    hook_event_name: str = "PreToolUse",
) -> tuple[int, str]:
    """Run the Claude hook with given tool call data.

    `hook_event_name` is what real Claude Code provides on every stdin
    payload; hooks assert it defensively, so tests must supply it. Defaults
    to PreToolUse since that's what most hook tests exercise.
    """
    requires_cmd("bash")
    stdin_data = json.dumps(
        {
            "hook_event_name": hook_event_name,
            "tool_name": tool_name,
            "tool_input": tool_input,
        }
    )

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
# Generic hook tests
# ---------------------------------------------------------------------------


class TestClaudeHooks:
    """Generic tests for Claude hooks."""

    def test_hooks_exist(self, dotconfigs_root: Path, available_claude_hooks):
        """All hooks listed in manifest actually exist as files."""
        if not available_claude_hooks:
            pytest.skip("No Claude hooks in manifest")

        hooks_dir = dotconfigs_root / "plugins" / "claude" / "hooks"

        for hook_name in available_claude_hooks:
            hook_file = hooks_dir / hook_name
            assert hook_file.exists(), f"Hook {hook_name} in manifest but not found"
            assert hook_file.is_file()

    def test_hooks_executable(self, dotconfigs_root: Path, available_claude_hooks):
        """All hook files have shebang."""
        if not available_claude_hooks:
            pytest.skip("No Claude hooks in manifest")

        hooks_dir = dotconfigs_root / "plugins" / "claude" / "hooks"

        for hook_name in available_claude_hooks:
            hook_file = hooks_dir / hook_name
            if hook_file.exists():
                content = hook_file.read_text()
                assert content.startswith("#!"), (
                    f"Hook {hook_name} should start with shebang"
                )

    def test_hook_accepts_safe_commands(self, hook_script):
        """Hook allows safe commands."""
        returncode, output = run_hook(hook_script, "Bash", {"command": "ls -la"})
        assert returncode == 0
        data = parse_hook_output(output)
        # Should allow (no output or no deny decision)
        if data:
            assert (
                data.get("hookSpecificOutput", {}).get("permissionDecision") != "deny"
            )

    def test_hook_accepts_safe_writes(self, hook_script):
        """Hook allows writes to normal files."""
        returncode, output = run_hook(
            hook_script,
            "Write",
            {"file_path": "/tmp/test.txt", "content": "data"},
        )
        assert returncode == 0
        data = parse_hook_output(output)
        if data:
            assert (
                data.get("hookSpecificOutput", {}).get("permissionDecision") != "deny"
            )


# ---------------------------------------------------------------------------
# PR attribution hook tests
# ---------------------------------------------------------------------------


class TestBlockAiPrAttribution:
    """Tests for the block-ai-pr-attribution hook."""

    @pytest.fixture
    def pr_hook(self, dotconfigs_root: Path, available_claude_hooks):
        hook_name = "block-ai-pr-attribution.sh"
        if hook_name not in available_claude_hooks:
            pytest.skip("block-ai-pr-attribution.sh not in manifest")
        return dotconfigs_root / "plugins" / "claude" / "hooks" / hook_name

    def test_allows_non_pr_commands(self, pr_hook):
        """Non-PR commands pass through."""
        returncode, output = run_hook(pr_hook, "Bash", {"command": "git status"})
        assert returncode == 0
        assert parse_hook_output(output) is None

    def test_allows_clean_pr(self, pr_hook):
        """PR without AI attribution is allowed."""
        cmd = 'gh pr create --title "fix: resolve null check" --body "Fixed the bug"'
        returncode, output = run_hook(pr_hook, "Bash", {"command": cmd})
        assert returncode == 0
        assert parse_hook_output(output) is None

    @pytest.mark.parametrize(
        "phrase",
        [
            "Generated by Claude",
            "Written with Claude",
            "written with cc",
            "AI-assisted",
            "Claude Code",
            "assisted by AI",
            "powered by Claude",
            "using Claude",
            "Co-Authored-By: Claude",
        ],
    )
    def test_blocks_ai_attribution(self, pr_hook, phrase):
        """PR with AI attribution patterns is denied."""
        cmd = f'gh pr create --title "feat: add feature" --body "{phrase}"'
        returncode, output = run_hook(pr_hook, "Bash", {"command": cmd})
        assert returncode == 0
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny", (
            f"Should have blocked: {phrase}"
        )

    def test_blocks_case_insensitive(self, pr_hook):
        """Attribution check is case-insensitive."""
        cmd = 'gh pr create --title "feat: thing" --body "WRITTEN BY AI"'
        returncode, output = run_hook(pr_hook, "Bash", {"command": cmd})
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"

    def test_ignores_non_bash_tools(self, pr_hook):
        """Non-Bash tool calls pass through."""
        returncode, output = run_hook(
            pr_hook, "Write", {"file_path": "/tmp/x", "content": "Claude Code"}
        )
        assert returncode == 0
        assert parse_hook_output(output) is None

    def test_blocks_pr_edit(self, pr_hook):
        """Also blocks gh pr edit with attribution."""
        cmd = 'gh pr edit 42 --body "Written with Claude"'
        returncode, output = run_hook(pr_hook, "Bash", {"command": cmd})
        data = parse_hook_output(output)
        assert data is not None
        assert data["hookSpecificOutput"]["permissionDecision"] == "deny"


# ---------------------------------------------------------------------------
# GitHub PR/issue write-guard hook tests
# ---------------------------------------------------------------------------


class TestBlockGhComment:
    """Tests for the block-gh-comment hook."""

    @pytest.fixture
    def gh_hook(self, dotconfigs_root: Path, available_claude_hooks):
        hook_name = "block-gh-comment.sh"
        if hook_name not in available_claude_hooks:
            pytest.skip("block-gh-comment.sh not in manifest")
        return dotconfigs_root / "plugins" / "claude" / "hooks" / hook_name

    @staticmethod
    def _is_deny(output: str) -> bool:
        data = parse_hook_output(output)
        return bool(data) and (
            data.get("hookSpecificOutput", {}).get("permissionDecision") == "deny"
        )

    @staticmethod
    def _is_ask(output: str) -> bool:
        data = parse_hook_output(output)
        return bool(data) and (
            data.get("hookSpecificOutput", {}).get("permissionDecision") == "ask"
        )

    @pytest.mark.parametrize(
        "cmd",
        [
            "git status",
            "gh pr view 213 --json body",
            "gh pr list --state open",
            # Reads against comment endpoints (no body params) must pass.
            "gh api repos/o/r/pulls/213/comments --jq '.[].id'",
            "gh api --paginate repos/o/r/issues/5/comments",
            # Explicit GET is a read even with body params (query filters).
            "gh api repos/o/r/pulls/213/comments -X GET -f per_page=100",
        ],
    )
    def test_allows_reads_and_unrelated(self, gh_hook, cmd):
        returncode, output = run_hook(gh_hook, "Bash", {"command": cmd})
        assert returncode == 0
        assert not self._is_deny(output), f"should allow: {cmd}"

    @pytest.mark.parametrize(
        "cmd",
        [
            'gh pr comment 213 --body "hi"',
            'gh issue comment 5 --body "hi"',
            "gh pr review 213 --approve",
            "gh api repos/o/r/pulls/213/comments/123/replies -X POST -f body=hi",
            "gh api -X PATCH repos/o/r/issues/comments/123 -f body=edited",
        ],
    )
    def test_blocks_explicit_writes(self, gh_hook, cmd):
        returncode, output = run_hook(gh_hook, "Bash", {"command": cmd})
        assert self._is_deny(output), f"should block: {cmd}"

    @pytest.mark.parametrize(
        "cmd",
        [
            # The exact form that slipped through: implicit POST, no -X.
            "gh api repos/o/r/pulls/213/comments/123/replies -f body='done'",
            "gh api repos/o/r/pulls/213/comments/123/replies -f body='x' --jq '.id'",
            "gh api repos/o/r/issues/5/comments -F body=@note.md",
            "gh api repos/o/r/pulls/213/reviews --input review.json",
            "gh api --method POST repos/o/r/pulls/213/comments -f body=hi",
        ],
    )
    def test_blocks_implicit_post(self, gh_hook, cmd):
        """gh infers POST from body params, so these are writes with no -X."""
        returncode, output = run_hook(gh_hook, "Bash", {"command": cmd})
        assert self._is_deny(output), f"should block implicit POST: {cmd}"

    def test_bypass_with_env_prefix(self, gh_hook):
        """GH_COMMENT_OK=1 prefix is the explicit-approval escape hatch."""
        cmd = "GH_COMMENT_OK=1 gh api repos/o/r/pulls/213/comments/123/replies -f body='ok'"
        returncode, output = run_hook(gh_hook, "Bash", {"command": cmd})
        assert not self._is_deny(output)

    def test_ignores_unrelated_non_bash(self, gh_hook):
        returncode, output = run_hook(
            gh_hook, "Write", {"file_path": "/tmp/x", "content": "gh pr comment 1 --body x"}
        )
        assert returncode == 0
        assert parse_hook_output(output) is None

    # --- GitHub MCP server entrypoint (mcp__github__*) ---

    @pytest.mark.parametrize(
        "tool_name",
        [
            "mcp__github__add_issue_comment",
            "mcp__github__create_pending_pull_request_review",
            "mcp__github__add_comment_to_pending_review",
            "mcp__github__submit_pending_pull_request_review",
            "mcp__github__create_and_submit_pull_request_review",
        ],
    )
    def test_mcp_comment_review_writes_ask(self, gh_hook, tool_name):
        """MCP comment/review posts return 'ask' (no env-prefix bypass possible)."""
        returncode, output = run_hook(gh_hook, tool_name, {"body": "hi"})
        assert returncode == 0
        assert self._is_ask(output), f"should ask: {tool_name}"

    @pytest.mark.parametrize(
        "tool_name",
        [
            # Reads — contain 'comment'/'review' but no write verb.
            "mcp__github__get_issue_comments",
            "mcp__github__get_pull_request_reviews",
            "mcp__github__list_issues",
            # Non-comment writes — out of scope.
            "mcp__github__create_pull_request",
            "mcp__github__update_issue",
            "mcp__github__merge_pull_request",
        ],
    )
    def test_mcp_reads_and_noncomment_writes_pass(self, gh_hook, tool_name):
        returncode, output = run_hook(gh_hook, tool_name, {})
        assert returncode == 0
        assert parse_hook_output(output) is None, f"should pass: {tool_name}"
