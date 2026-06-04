"""Tests for the scope-correctness fixes.

These pin the behaviours that, when broken, let AI attribution slip through and
left global-deployed git hooks inert:

- git hooks are seeded into new repos via `init.templateDir` (global-deploy's
  real job) and installed into existing repos per-project (`.git/hooks`);
- the settings.json merge replaces the `hooks` array wholesale with the plugin
  source (so a re-deploy actually propagates new hook wiring — no silent drift);
- a defensive guard flags claude hooks wired in BOTH global and project scope
  (Claude merges hooks additively → double-fire);
- `dotconfigs status` audits registered repos for missing/dangling git hooks.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit

REPO_ROOT = Path(__file__).resolve().parent.parent


# ---------------------------------------------------------------------------
# git plugin scope: templateDir seeding, no inert global hooks dir
# ---------------------------------------------------------------------------


def test_git_global_hooks_target_is_template_dir():
    """Global git hooks land in the git template dir, not the inert git-hooks dir.

    The old `~/.dotconfigs/git-hooks` target was never read by git (no
    core.hooksPath / templateDir pointed at it), so hooks deployed there never
    fired. They must live under the template dir git actually seeds from.
    """
    manifest = json.loads((REPO_ROOT / "plugins/git/manifest.json").read_text())
    target = manifest["global"]["hooks"]["target"]
    assert target == "~/.dotconfigs/git-template/hooks", target
    # The dead inert directory must not reappear.
    assert "git-hooks" not in target


def test_gitconfig_wires_init_templatedir():
    """gitconfig sets init.templateDir so new repos auto-install the hooks."""
    gitconfig = (REPO_ROOT / "plugins/git/templates/gitconfig").read_text()
    assert "templateDir = ~/.dotconfigs/git-template" in gitconfig


def test_git_hooks_still_project_scoped():
    """Existing repos are covered per-project: project hooks → .git/hooks."""
    manifest = json.loads((REPO_ROOT / "plugins/git/manifest.json").read_text())
    assert manifest["project"]["hooks"]["target"] == ".git/hooks"


def test_templatedir_seeds_new_repo(tmp_path: Path):
    """End-to-end: a git template dir of symlinked hooks seeds a new repo.

    Verifies the mechanism the gitconfig relies on — git preserves the symlinks
    when copying the template into a fresh repo's .git/hooks, and they resolve.
    """
    template_hooks = tmp_path / "template" / "hooks"
    template_hooks.mkdir(parents=True)
    real = tmp_path / "commit-msg-src"
    real.write_text("#!/bin/bash\nexit 0\n")
    real.chmod(0o755)
    (template_hooks / "commit-msg").symlink_to(real)

    subprocess.run(
        ["git", "init", "--template", str(tmp_path / "template"), str(tmp_path / "repo")],
        capture_output=True,
        check=True,
    )
    seeded = tmp_path / "repo" / ".git" / "hooks" / "commit-msg"
    assert seeded.is_symlink(), "templateDir should preserve the hook symlink"
    assert seeded.resolve() == real.resolve()


# ---------------------------------------------------------------------------
# merge semantics: a re-deploy propagates changed hook wiring (no silent drift)
# ---------------------------------------------------------------------------


def _merge(root: Path, source: Path, target: Path):
    script = f"""
set -e
source "{root}/lib/symlinks.sh"
source "{root}/lib/validation.sh"
source "{root}/lib/deploy.sh"
_rc=0
merge_json_settings "{source}" "{target}" || _rc=$?
echo "RC=$_rc"
"""
    return run_bash(script)


def test_merge_replaces_hooks_array_wholesale(dotconfigs_root, tmp_path: Path):
    """The merge overwrites the live `hooks` array with the plugin source.

    This is what makes "just re-run deploy" a real fix for stale hook wiring:
    jq `*` replaces arrays (RHS/source wins), so a hook added to the source
    propagates to the live file instead of being frozen at first-deploy state.
    """
    # Live file: one hook wired, plus a locally-granted permission to preserve.
    live = tmp_path / "settings.json"
    live.write_text(
        json.dumps(
            {
                "permissions": {"allow": ["Bash(local-grant:*)"]},
                "hooks": {
                    "PreToolUse": [
                        {"matcher": "Bash", "hooks": [{"command": "old.sh"}]}
                    ]
                },
            }
        )
    )
    # Source: two hooks now wired.
    source = tmp_path / "source.json"
    source.write_text(
        json.dumps(
            {
                "hooks": {
                    "PreToolUse": [
                        {
                            "matcher": "Bash",
                            "hooks": [{"command": "old.sh"}, {"command": "new.sh"}],
                        }
                    ]
                },
            }
        )
    )

    res = _merge(dotconfigs_root, source, live)
    assert "RC=0" in res.stdout, res.stderr

    merged = json.loads(live.read_text())
    cmds = [h["command"] for h in merged["hooks"]["PreToolUse"][0]["hooks"]]
    assert cmds == ["old.sh", "new.sh"], "source hook array must win wholesale"
    # Local permission grant survives (unioned, not clobbered).
    assert "Bash(local-grant:*)" in merged["permissions"]["allow"]


# ---------------------------------------------------------------------------
# defensive guard: cross-scope hook duplication (additive merge → double-fire)
# ---------------------------------------------------------------------------


def _dup_check(root: Path, global_json: Path, project_json: Path):
    script = f"""
source "{root}/lib/colours.sh"
source "{root}/lib/refcheck.sh"
warnings=0
_rc=0
refcheck_hook_duplication "{global_json}" "{project_json}" || _rc=$?
echo "RC=$_rc WARN=$warnings"
"""
    return run_bash(script)


def _settings_with_hook(path: Path, event: str, command: str):
    path.write_text(
        json.dumps(
            {"hooks": {event: [{"matcher": "Bash", "hooks": [{"command": command}]}]}}
        )
    )


def test_dup_guard_flags_same_hook_both_scopes(dotconfigs_root, tmp_path: Path):
    """Same script + same event in global and project scope → flagged."""
    g = tmp_path / "global.json"
    p = tmp_path / "project.json"
    # Different path prefixes, same script basename = the real double-fire case.
    _settings_with_hook(g, "PreToolUse", "~/.claude/hooks/block-rm.sh")
    _settings_with_hook(p, "PreToolUse", "${CLAUDE_PROJECT_DIR}/.claude/hooks/block-rm.sh")

    res = _dup_check(dotconfigs_root, g, p)
    assert "RC=1" in res.stdout, res.stdout
    assert "WARN=1" in res.stdout
    assert "block-rm.sh" in res.stderr
    assert "fire twice" in res.stderr


def test_dup_guard_quiet_when_distinct(dotconfigs_root, tmp_path: Path):
    """Different hooks per scope, or different events, are not flagged."""
    g = tmp_path / "global.json"
    p = tmp_path / "project.json"
    _settings_with_hook(g, "PreToolUse", "~/.claude/hooks/block-rm.sh")
    _settings_with_hook(p, "PreToolUse", "${CLAUDE_PROJECT_DIR}/.claude/hooks/repo-only.sh")

    res = _dup_check(dotconfigs_root, g, p)
    assert "RC=0" in res.stdout, res.stdout
    assert "WARN=0" in res.stdout


def test_dup_guard_same_script_different_event_ok(dotconfigs_root, tmp_path: Path):
    """Same script on different events does not double-fire — not flagged."""
    g = tmp_path / "global.json"
    p = tmp_path / "project.json"
    _settings_with_hook(g, "PreToolUse", "~/.claude/hooks/x.sh")
    _settings_with_hook(p, "PostToolUse", "${CLAUDE_PROJECT_DIR}/.claude/hooks/x.sh")

    res = _dup_check(dotconfigs_root, g, p)
    assert "RC=0" in res.stdout, res.stdout


# ---------------------------------------------------------------------------
# status audit: registered repos with missing/dangling git hooks
# ---------------------------------------------------------------------------


def _init_repo_with_hooks(path: Path, hooks: list[str]):
    subprocess.run(["git", "init", str(path)], capture_output=True, check=True)
    hookdir = path / ".git" / "hooks"
    hookdir.mkdir(parents=True, exist_ok=True)
    for h in hooks:
        f = hookdir / h
        f.write_text("#!/bin/bash\nexit 0\n")
        f.chmod(0o755)


def test_status_audit_flags_missing_hooks(dotconfigs_root, tmp_path: Path):
    """A registered repo lacking its git hooks is reported as missing."""
    repo = tmp_path / "barerepo"
    _init_repo_with_hooks(repo, [])  # git repo, but no dotconfigs hooks

    registry = tmp_path / "projects.list"
    registry.write_text(str(repo) + "\n")

    res = run_bash(
        f'"{dotconfigs_root}/dotconfigs" status git',
        env={
            "HOME": str(tmp_path / "home"),
            "DOTCONFIGS_PROJECT_REGISTRY": str(registry),
        },
    )
    out = res.stdout + res.stderr
    assert "project git-hook audit" in out
    assert str(repo) in out
    assert "missing" in out


def test_status_audit_passes_repo_with_hooks(dotconfigs_root, tmp_path: Path):
    """A registered repo with all expected hooks present audits clean."""
    manifest = json.loads((dotconfigs_root / "plugins/git/manifest.json").read_text())
    expected = manifest["project"]["hooks"]["include"]

    repo = tmp_path / "goodrepo"
    _init_repo_with_hooks(repo, expected)

    registry = tmp_path / "projects.list"
    registry.write_text(str(repo) + "\n")

    res = run_bash(
        f'"{dotconfigs_root}/dotconfigs" status git',
        env={
            "HOME": str(tmp_path / "home"),
            "DOTCONFIGS_PROJECT_REGISTRY": str(registry),
        },
    )
    out = res.stdout + res.stderr
    assert str(repo) in out
    assert "missing" not in out.split("project git-hook audit", 1)[-1]
