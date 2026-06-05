"""Per-hook tests for the claude lifecycle hooks.

Covers the non-PreToolUse event hooks added for context injection, venv
activation, session telemetry, transcript snapshots, and notification fan-out.
Each hook asserts its own hook_event_name and no-ops on a mismatch, so every
hook gets: a wrong-event no-op test plus its happy/skip paths.

HOME is always redirected to a temp dir so hooks never write to the real
~/.claude/ telemetry files.
"""

from __future__ import annotations

import json
import os
import subprocess
from pathlib import Path

import pytest

from tests.conftest import requires_cmd

pytestmark = pytest.mark.unit

HOOKS_REL = ("plugins", "claude", "hooks")


def _hook(dotconfigs_root: Path, name: str) -> Path:
    path = dotconfigs_root.joinpath(*HOOKS_REL, name)
    if not path.exists():
        pytest.skip(f"{name} not present")
    return path


def run_hook(path: Path, payload: dict, *, home: Path, env: dict | None = None):
    """Run a lifecycle hook with a JSON stdin payload and an isolated HOME."""
    requires_cmd("bash")
    requires_cmd("jq")
    base = {**os.environ, "HOME": str(home)}
    # Drop any project context inherited from the test runner; tests opt in.
    base.pop("CLAUDE_PROJECT_DIR", None)
    base.pop("CLAUDE_ENV_FILE", None)
    if env:
        base.update(env)
    return subprocess.run(
        ["bash", str(path)],
        input=json.dumps(payload),
        capture_output=True,
        text=True,
        env=base,
    )


def _git_repo(path: Path) -> Path:
    path.mkdir(parents=True, exist_ok=True)

    def run(*a):
        return subprocess.run(
            ["git", "-C", str(path), *a], check=True, capture_output=True
        )

    run("init", "-q")
    run("config", "user.email", "t@example.com")
    run("config", "user.name", "Test")
    (path / "f.txt").write_text("hi\n")
    run("add", "f.txt")
    run("commit", "-q", "-m", "init")
    return path


@pytest.fixture
def home(tmp_path: Path) -> Path:
    h = tmp_path / "home"
    h.mkdir()
    return h


# ---------------------------------------------------------------------------
# inject-context.sh (UserPromptSubmit)
# ---------------------------------------------------------------------------


def test_inject_context_wrong_event_noop(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "inject-context.sh"),
        {"hook_event_name": "PreToolUse"},
        home=home,
    )
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_inject_context_outside_git_noop(dotconfigs_root, home, tmp_path):
    nongit = tmp_path / "plain"
    nongit.mkdir()
    r = run_hook(
        _hook(dotconfigs_root, "inject-context.sh"),
        {"hook_event_name": "UserPromptSubmit"},
        home=home,
        env={"CLAUDE_PROJECT_DIR": str(nongit)},
    )
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_inject_context_in_git_repo(dotconfigs_root, home, tmp_path):
    requires_cmd("git")
    repo = _git_repo(tmp_path / "repo")
    r = run_hook(
        _hook(dotconfigs_root, "inject-context.sh"),
        {"hook_event_name": "UserPromptSubmit"},
        home=home,
        env={"CLAUDE_PROJECT_DIR": str(repo)},
    )
    assert r.returncode == 0
    data = json.loads(r.stdout)
    ctx = data["hookSpecificOutput"]["additionalContext"]
    assert ctx.startswith("[context: branch=")
    assert "dirty=0 modified" in ctx


# ---------------------------------------------------------------------------
# session-start-env.sh (SessionStart)
# ---------------------------------------------------------------------------


def test_session_start_wrong_event_noop(dotconfigs_root, home, tmp_path):
    env_file = tmp_path / "env"
    env_file.write_text("")
    r = run_hook(
        _hook(dotconfigs_root, "session-start-env.sh"),
        {"hook_event_name": "PreToolUse"},
        home=home,
        env={"CLAUDE_ENV_FILE": str(env_file), "CLAUDE_PROJECT_DIR": str(tmp_path)},
    )
    assert r.returncode == 0
    assert env_file.read_text() == ""


def test_session_start_activates_venv(dotconfigs_root, home, tmp_path):
    proj = tmp_path / "proj"
    (proj / ".venv" / "bin").mkdir(parents=True)
    (proj / ".venv" / "bin" / "activate").write_text("# venv\n")
    env_file = tmp_path / "env"
    env_file.write_text("")
    r = run_hook(
        _hook(dotconfigs_root, "session-start-env.sh"),
        {"hook_event_name": "SessionStart"},
        home=home,
        env={"CLAUDE_ENV_FILE": str(env_file), "CLAUDE_PROJECT_DIR": str(proj)},
    )
    assert r.returncode == 0
    content = env_file.read_text()
    assert f"VIRTUAL_ENV={proj}/.venv" in content
    assert f"PATH={proj}/.venv/bin:" in content


def test_session_start_no_venv_noop(dotconfigs_root, home, tmp_path):
    proj = tmp_path / "proj"
    proj.mkdir()
    env_file = tmp_path / "env"
    env_file.write_text("")
    r = run_hook(
        _hook(dotconfigs_root, "session-start-env.sh"),
        {"hook_event_name": "SessionStart"},
        home=home,
        env={"CLAUDE_ENV_FILE": str(env_file), "CLAUDE_PROJECT_DIR": str(proj)},
    )
    assert r.returncode == 0
    assert env_file.read_text() == ""


# ---------------------------------------------------------------------------
# session-end-log.sh (SessionEnd)
# ---------------------------------------------------------------------------


def test_session_end_wrong_event_noop(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "session-end-log.sh"),
        {"hook_event_name": "PreToolUse"},
        home=home,
    )
    assert r.returncode == 0
    assert not (home / ".claude" / "session-log.jsonl").exists()


def test_session_end_appends_jsonl(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "session-end-log.sh"),
        {
            "hook_event_name": "SessionEnd",
            "session_id": "sess-123",
            "duration_seconds": 42,
            "model": "claude-opus-4-8",
            "cwd": "/some/project",
        },
        home=home,
    )
    assert r.returncode == 0
    log = home / ".claude" / "session-log.jsonl"
    assert log.exists()
    entry = json.loads(log.read_text().strip())
    assert entry["session_id"] == "sess-123"
    assert entry["model"] == "claude-opus-4-8"
    assert entry["duration_seconds"] == 42  # coerced to a JSON number
    assert entry["project_dir"] == "/some/project"


# ---------------------------------------------------------------------------
# pre-compact-snapshot.sh (PreCompact)
# ---------------------------------------------------------------------------


def test_precompact_wrong_event_noop(dotconfigs_root, home, tmp_path):
    transcript = tmp_path / "t.jsonl"
    transcript.write_text("line\n")
    r = run_hook(
        _hook(dotconfigs_root, "pre-compact-snapshot.sh"),
        {
            "hook_event_name": "PreToolUse",
            "transcript_path": str(transcript),
            "session_id": "x",
        },
        home=home,
    )
    assert r.returncode == 0
    assert not (home / ".claude" / "snapshots").exists()


def test_precompact_snapshots_transcript(dotconfigs_root, home, tmp_path):
    transcript = tmp_path / "t.jsonl"
    transcript.write_text('{"a":1}\n')
    r = run_hook(
        _hook(dotconfigs_root, "pre-compact-snapshot.sh"),
        {
            "hook_event_name": "PreCompact",
            "transcript_path": str(transcript),
            "session_id": "abc",
        },
        home=home,
    )
    assert r.returncode == 0
    snap = home / ".claude" / "snapshots" / "abc-precompact.jsonl"
    assert snap.exists()
    assert snap.read_text() == '{"a":1}\n'


def test_precompact_missing_transcript_noop(dotconfigs_root, home, tmp_path):
    r = run_hook(
        _hook(dotconfigs_root, "pre-compact-snapshot.sh"),
        {
            "hook_event_name": "PreCompact",
            "transcript_path": str(tmp_path / "gone.jsonl"),
            "session_id": "abc",
        },
        home=home,
    )
    assert r.returncode == 0
    assert not (home / ".claude" / "snapshots" / "abc-precompact.jsonl").exists()


# ---------------------------------------------------------------------------
# notify.sh (Notification)
# ---------------------------------------------------------------------------


def _no_channels() -> dict:
    # No ntfy topic, no display => both fan-out paths are skipped cleanly.
    return {"NTFY_TOPIC": "", "DISPLAY": "", "WAYLAND_DISPLAY": ""}


def test_notify_wrong_event_noop(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "notify.sh"),
        {"hook_event_name": "PreToolUse", "message": "hi"},
        home=home,
        env=_no_channels(),
    )
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_notify_no_channels_graceful(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "notify.sh"),
        {"hook_event_name": "Notification", "message": "build done"},
        home=home,
        env=_no_channels(),
    )
    assert r.returncode == 0
    assert r.stdout.strip() == ""


def test_notify_empty_message_noop(dotconfigs_root, home):
    r = run_hook(
        _hook(dotconfigs_root, "notify.sh"),
        {"hook_event_name": "Notification", "message": ""},
        home=home,
        env=_no_channels(),
    )
    assert r.returncode == 0
