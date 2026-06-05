"""Tests for scope-correctness and the attribution guards.

These pin behaviours that, when broken, let AI attribution slip through or leave
git hooks inert:

- git hooks deploy to BOTH the git template dir (seeds new repos via
  init.templateDir) and a repo's .git/hooks (covers existing repos);
- the settings.json merge replaces the `hooks` array wholesale (so a re-deploy
  propagates new hook wiring — no silent drift);
- init.templateDir is coupled to the git hooks selection (toggling them off
  clears it);
- `dotconfigs status` audits registered repos for missing/dangling git hooks;
- the attribution guards block AI attribution across every guarded surface.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit

REPO_ROOT = Path(__file__).resolve().parent.parent
ENTRY = REPO_ROOT / "src" / "dotconfigs"


# ---------------------------------------------------------------------------
# git plugin scope: dual targets (template dir + .git/hooks)
# ---------------------------------------------------------------------------


def test_git_hooks_have_template_and_project_targets():
    manifest = json.loads((REPO_ROOT / "plugins/git/manifest.json").read_text())
    targets = manifest["hooks"]["commit-msg"]["target"]
    assert "~/.dotconfigs/git-template/hooks/commit-msg" in targets
    assert ".git/hooks/commit-msg" in targets


def test_gitconfig_does_not_hardcode_templatedir():
    """init.templateDir is managed imperatively by deploy, never baked into the
    static gitconfig — a hardcoded line would defeat the off-switch."""
    gitconfig = (REPO_ROOT / "plugins/git/templates/gitconfig").read_text()
    assert "templateDir = ~/.dotconfigs/git-template" not in gitconfig


def test_templatedir_seeds_new_repo(tmp_path: Path):
    """git preserves the symlinked hooks when seeding a new repo from a template."""
    template_hooks = tmp_path / "template" / "hooks"
    template_hooks.mkdir(parents=True)
    real = tmp_path / "commit-msg-src"
    real.write_text("#!/bin/bash\nexit 0\n")
    real.chmod(0o755)
    (template_hooks / "commit-msg").symlink_to(real)

    subprocess.run(
        [
            "git",
            "init",
            "--template",
            str(tmp_path / "template"),
            str(tmp_path / "repo"),
        ],
        capture_output=True,
        check=True,
    )
    seeded = tmp_path / "repo" / ".git" / "hooks" / "commit-msg"
    assert seeded.is_symlink()
    assert seeded.resolve() == real.resolve()


# ---------------------------------------------------------------------------
# merge semantics: a re-deploy propagates changed hook wiring (no silent drift)
# ---------------------------------------------------------------------------


def _merge(root: Path, source: Path, target: Path):
    script = f"""
set -e
source "{root}/src/lib/symlinks.sh"
source "{root}/src/lib/validation.sh"
source "{root}/src/lib/deploy.sh"
_rc=0
merge_json_settings "{source}" "{target}" || _rc=$?
echo "RC=$_rc"
"""
    return run_bash(script)


def test_merge_replaces_hooks_array_wholesale(dotconfigs_root, tmp_path: Path):
    """jq `*` replaces arrays (source wins), so synthesised hook wiring propagates
    to the live file instead of being frozen at first-deploy state; local
    permission grants survive."""
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
                }
            }
        )
    )

    res = _merge(dotconfigs_root, source, live)
    assert "RC=0" in res.stdout, res.stderr
    merged = json.loads(live.read_text())
    cmds = [h["command"] for h in merged["hooks"]["PreToolUse"][0]["hooks"]]
    assert cmds == ["old.sh", "new.sh"]
    assert "Bash(local-grant:*)" in merged["permissions"]["allow"]


# ---------------------------------------------------------------------------
# init.templateDir coupled to the git hooks selection
# ---------------------------------------------------------------------------


def test_templatedir_coupled_to_hooks(dotconfigs_root, tmp_path: Path):
    """templateDir is set when any git hook is selected and cleared when none are
    — so turning off git seeding is just toggling the hooks off in deploy.json."""
    gitconfig = tmp_path / "gitconfig"
    gitconfig.write_text("")

    def deploy(deploy_json: Path):
        return run_bash(
            f'"{ENTRY}" deploy --force',
            env={
                "HOME": str(tmp_path / "home"),
                "GIT_CONFIG_GLOBAL": str(gitconfig),
                "GIT_CONFIG_SYSTEM": str(gitconfig),
                "DOTCONFIGS_DEPLOY_CONFIG": str(deploy_json),
                "DOTCONFIGS_PROJECT_REGISTRY": str(tmp_path / "reg.list"),
            },
        )

    def templatedir():
        res = run_bash(
            "git config --global --get init.templateDir || true",
            env={"GIT_CONFIG_GLOBAL": str(gitconfig)},
        )
        return res.stdout.strip()

    with_hooks = tmp_path / "with.json"
    with_hooks.write_text(json.dumps({"git": {"hooks": {"commit-msg": True}}}))
    assert deploy(with_hooks).returncode == 0
    assert templatedir() == "~/.dotconfigs/git-template"

    without_hooks = tmp_path / "without.json"
    without_hooks.write_text(json.dumps({"git": {"hooks": {"commit-msg": False}}}))
    assert deploy(without_hooks).returncode == 0
    assert templatedir() == ""


# ---------------------------------------------------------------------------
# status audit: registered repos with missing/dangling git hooks
# ---------------------------------------------------------------------------


def _audit(registry: Path, home: Path) -> str:
    res = run_bash(
        f'"{ENTRY}" status git',
        env={"HOME": str(home), "DOTCONFIGS_PROJECT_REGISTRY": str(registry)},
    )
    return res.stdout + res.stderr


def _home_with_selection(tmp_path: Path) -> Path:
    """A temp HOME with an (empty) machine deploy.json so `status` clears its gate."""
    home = tmp_path / "home"
    (home / ".dotconfigs").mkdir(parents=True)
    (home / ".dotconfigs" / "deploy.json").write_text("{}")
    return home


def test_status_audit_flags_missing_hooks(tmp_path: Path):
    repo = tmp_path / "barerepo"
    subprocess.run(
        ["git", "init", "--template=", str(repo)], capture_output=True, check=True
    )
    registry = tmp_path / "projects.list"
    registry.write_text(str(repo) + "\n")

    out = _audit(registry, _home_with_selection(tmp_path))
    assert "project git-hook audit" in out
    assert str(repo) in out
    assert "missing" in out


def test_status_audit_clean_then_flags_drift(run_dotconfigs, tmp_path: Path):
    repo = tmp_path / "repo"
    subprocess.run(
        ["git", "init", "--template=", str(repo)], capture_output=True, check=True
    )
    home = _home_with_selection(tmp_path)
    env = {
        "HOME": str(home),
        "DOTCONFIGS_DEPLOY_CONFIG": str(home / ".dotconfigs" / "deploy.json"),
        "DOTCONFIGS_PROJECT_REGISTRY": str(tmp_path / "projects.list"),
    }
    assert run_dotconfigs(["init", str(repo), "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", str(repo), "--force"], env=env).returncode == 0

    clean = run_dotconfigs(["status", "git"], env=env)
    audit = (clean.stdout + clean.stderr).split("project git-hook audit", 1)[-1]
    assert str(repo) in audit
    assert "missing" not in audit and "dangling" not in audit

    (repo / ".git" / "hooks" / "commit-msg").unlink()
    drifted = run_dotconfigs(["status", "git"], env=env)
    drift_audit = (drifted.stdout + drifted.stderr).split("project git-hook audit", 1)[
        -1
    ]
    assert str(repo) in drift_audit
    assert "commit-msg" in drift_audit
    assert "missing" in drift_audit


# ---------------------------------------------------------------------------
# attribution guards: must BLOCK across every guarded surface
# ---------------------------------------------------------------------------

ATTR_HOOK = REPO_ROOT / "plugins/claude/hooks/block-ai-pr-attribution.sh"

_ATTR_DENY_CASES = [
    (
        "bash_gh_pr",
        {
            "tool_name": "Bash",
            "tool_input": {"command": 'gh pr create --body "Co-Authored-By: Claude"'},
        },
    ),
    (
        "mcp_create_pr",
        {
            "tool_name": "mcp__github__create_pull_request",
            "tool_input": {"title": "t", "body": "Generated with Claude"},
        },
    ),
    (
        "mcp_update_pr",
        {
            "tool_name": "mcp__github__update_pull_request",
            "tool_input": {"body": "written with cc"},
        },
    ),
    (
        "mcp_push_files",
        {
            "tool_name": "mcp__github__push_files",
            "tool_input": {"message": "fix\n\nCo-Authored-By: Claude"},
        },
    ),
    (
        "mcp_cou_file",
        {
            "tool_name": "mcp__github__create_or_update_file",
            "tool_input": {"message": "AI-assisted change"},
        },
    ),
    (
        "mcp_merge_pr",
        {
            "tool_name": "mcp__github__merge_pull_request",
            "tool_input": {"commit_message": "merge\n\nGenerated by Claude"},
        },
    ),
    (
        "mcp_issue_comment",
        {
            "tool_name": "mcp__github__add_issue_comment",
            "tool_input": {"body": "powered by Claude"},
        },
    ),
]

_ATTR_ALLOW_CASES = [
    (
        "bash_gh_pr_clean",
        {
            "tool_name": "Bash",
            "tool_input": {"command": "gh pr create --body normal-description"},
        },
    ),
    (
        "mcp_create_pr_clean",
        {
            "tool_name": "mcp__github__create_pull_request",
            "tool_input": {"title": "t", "body": "a real summary"},
        },
    ),
    ("bash_non_pr", {"tool_name": "Bash", "tool_input": {"command": "git status"}}),
]


def _run_attr_hook(payload: dict):
    body = {"hook_event_name": "PreToolUse", **payload}
    return run_bash(f'printf %s {json.dumps(json.dumps(body))} | "{ATTR_HOOK}"')


@pytest.mark.parametrize(
    "label,payload", _ATTR_DENY_CASES, ids=[c[0] for c in _ATTR_DENY_CASES]
)
def test_attribution_blocked_on_every_surface(label, payload):
    res = _run_attr_hook(payload)
    assert '"permissionDecision": "deny"' in res.stdout, (
        f"{label} not blocked: {res.stdout}{res.stderr}"
    )


@pytest.mark.parametrize(
    "label,payload", _ATTR_ALLOW_CASES, ids=[c[0] for c in _ATTR_ALLOW_CASES]
)
def test_clean_payloads_pass(label, payload):
    res = _run_attr_hook(payload)
    assert '"permissionDecision": "deny"' not in res.stdout, f"{label} wrongly blocked"


def test_commit_msg_hook_blocks_attribution(tmp_path: Path):
    hook = REPO_ROOT / "plugins/git/hooks/commit-msg"
    dirty = tmp_path / "dirty.txt"
    dirty.write_text("fix: thing\n\nCo-Authored-By: Claude <noreply@anthropic.com>\n")
    assert run_bash(f'"{hook}" "{dirty}"').returncode != 0

    clean = tmp_path / "clean.txt"
    clean.write_text("fix: a clean conventional commit message\n")
    assert run_bash(f'"{hook}" "{clean}"').returncode == 0
