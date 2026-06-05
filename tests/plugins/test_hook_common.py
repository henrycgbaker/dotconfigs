"""Tests for plugins/claude/hooks/_hook-common.sh.

Exercises the shared hook helpers in isolation: required-command gating and
JSON-escaped deny/ask emission.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit


@pytest.fixture
def common_sh(dotconfigs_root: Path) -> Path:
    path = dotconfigs_root / "plugins" / "claude" / "hooks" / "_hook-common.sh"
    if not path.exists():
        pytest.skip("_hook-common.sh not present")
    return path


def _src(common: Path) -> str:
    return f'source "{common}"'


# ---------------------------------------------------------------------------
# hook_require_cmd
# ---------------------------------------------------------------------------


def test_require_cmd_continues_when_present(common_sh):
    script = f"{_src(common_sh)}\nhook_require_cmd bash\necho REACHED"
    result = run_bash(script)
    assert result.returncode == 0
    assert "REACHED" in result.stdout


def test_require_cmd_exits_when_missing(common_sh):
    script = f"{_src(common_sh)}\nhook_require_cmd definitely-not-a-real-cmd-xyz\necho REACHED"
    result = run_bash(script)
    assert result.returncode == 0  # silent no-op, not an error
    assert "REACHED" not in result.stdout


# ---------------------------------------------------------------------------
# hook_deny / hook_ask
# ---------------------------------------------------------------------------


def test_deny_emits_valid_escaped_json(common_sh):
    # A reason with quotes and a newline must survive as valid JSON.
    script = f"{_src(common_sh)}\nhook_deny 'blocked \"x\"\nline2'"
    result = run_bash(script)
    assert result.returncode == 0
    data = json.loads(result.stdout)
    out = data["hookSpecificOutput"]
    assert out["hookEventName"] == "PreToolUse"
    assert out["permissionDecision"] == "deny"
    assert out["permissionDecisionReason"] == 'blocked "x"\nline2'


def test_ask_emits_ask_decision(common_sh):
    script = f"{_src(common_sh)}\nhook_ask 'needs approval'"
    result = run_bash(script)
    assert result.returncode == 0
    data = json.loads(result.stdout)
    assert data["hookSpecificOutput"]["permissionDecision"] == "ask"
    assert data["hookSpecificOutput"]["permissionDecisionReason"] == "needs approval"
