"""Tests for _claude_merge_settings.

settings.json is co-owned: Claude Code appends permission grants the user
approves. So dotconfigs deploys it by MERGE (regular file), never symlink or
clobbering copy - local grants must survive every deploy.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.conftest import requires_cmd, run_bash_function

# Managed base (what the repo owns).
BASE = {
    "hooks": {"PreToolUse": [{"x": "BASE_HOOK"}]},
    "env": {"BASE_ENV": "1"},
    "permissions": {"allow": ["Bash(base-1)", "Bash(base-2)"]},
}
# Live file as it exists on a machine: accumulated grants + a local-only key +
# a stale managed key the base should overwrite.
LIVE = {
    "hooks": {"PreToolUse": [{"x": "STALE_HOOK"}]},
    "agentPushNotifEnabled": True,
    "permissions": {
        "allow": ["Bash(LOCAL_GRANT)", "Bash(base-1)"],
        "deny": ["Bash(rm -rf /)"],
    },
}


def _merge(dotconfigs_root: Path, source: Path, target: Path):
    return run_bash_function(
        dotconfigs_root,
        "lib/deploy.sh",
        "merge_json_settings",
        [str(source), str(target)],
    )


@pytest.fixture()
def merged(tmp_path: Path, dotconfigs_root: Path) -> Path:
    requires_cmd("jq")
    source = tmp_path / "source.json"
    target = tmp_path / "live.json"
    source.write_text(json.dumps(BASE))
    target.write_text(json.dumps(LIVE))
    result = _merge(dotconfigs_root, source, target)
    assert result.returncode == 0, result.stderr
    return target


class TestSettingsMerge:
    def test_result_is_regular_file_not_symlink(self, merged: Path) -> None:
        assert merged.is_file() and not merged.is_symlink()

    def test_base_wins_on_managed_keys(self, merged: Path) -> None:
        d = json.loads(merged.read_text())
        assert d["hooks"]["PreToolUse"][0]["x"] == "BASE_HOOK"  # stale overwritten
        assert d["env"]["BASE_ENV"] == "1"

    def test_local_grants_preserved(self, merged: Path) -> None:
        d = json.loads(merged.read_text())
        assert "Bash(LOCAL_GRANT)" in d["permissions"]["allow"]
        assert "Bash(rm -rf /)" in d["permissions"]["deny"]

    def test_base_rules_present_and_unioned(self, merged: Path) -> None:
        allow = json.loads(merged.read_text())["permissions"]["allow"]
        assert {"Bash(base-1)", "Bash(base-2)"} <= set(allow)
        assert allow.count("Bash(base-1)") == 1  # union dedups the shared rule

    def test_local_only_key_preserved(self, merged: Path) -> None:
        assert json.loads(merged.read_text())["agentPushNotifEnabled"] is True

    def test_idempotent(
        self, merged: Path, tmp_path: Path, dotconfigs_root: Path
    ) -> None:
        before = merged.read_text()
        result = _merge(dotconfigs_root, tmp_path / "source.json", merged)
        assert result.returncode == 0, result.stderr
        assert merged.read_text() == before

    def test_first_deploy_creates_from_base(
        self, tmp_path: Path, dotconfigs_root: Path
    ) -> None:
        requires_cmd("jq")
        source = tmp_path / "source.json"
        target = tmp_path / "absent.json"
        source.write_text(json.dumps(BASE))
        assert _merge(dotconfigs_root, source, target).returncode == 0
        assert target.is_file() and not target.is_symlink()
        assert (
            json.loads(target.read_text())["permissions"]["allow"]
            == BASE["permissions"]["allow"]
        )

    def test_stale_symlink_target_becomes_regular_file(
        self, tmp_path: Path, dotconfigs_root: Path
    ) -> None:
        requires_cmd("jq")
        source = tmp_path / "source.json"
        source.write_text(json.dumps(BASE))
        target = tmp_path / "linked.json"
        target.symlink_to(source)  # legacy: target was a symlink into the repo
        assert _merge(dotconfigs_root, source, target).returncode == 0
        assert target.is_file() and not target.is_symlink()
