"""Runtime tests: undeploy removes deployed artefacts without harming foreign files."""

from __future__ import annotations

import subprocess

import pytest

pytestmark = pytest.mark.e2e


def _env(home):
    return {
        "HOME": str(home),
        "DOTCONFIGS_DEPLOY_CONFIG": str(home / ".dotconfigs" / "deploy.json"),
    }


def test_undeploy_removes_symlinks_preserves_foreign(tmp_path, run_dotconfigs):
    home = tmp_path / "home"
    home.mkdir()
    env = _env(home)

    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0

    hook = home / ".claude" / "hooks" / "block-rm-rf-root.sh"
    assert hook.is_symlink()

    # A foreign file in a dotconfigs-managed directory must survive undeploy.
    foreign = home / ".claude" / "hooks" / "my-own.sh"
    foreign.write_text("# mine\n")

    result = run_dotconfigs(["undeploy", "--apply"], env=env)
    assert result.returncode == 0, result.stderr

    assert not hook.exists(), "deployed symlink should be removed"
    assert foreign.exists(), "foreign file must be preserved"


def test_undeploy_dry_run_changes_nothing(tmp_path, run_dotconfigs):
    home = tmp_path / "home"
    home.mkdir()
    env = _env(home)
    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0

    hook = home / ".claude" / "hooks" / "block-rm-rf-root.sh"
    assert hook.is_symlink()

    result = run_dotconfigs(["undeploy"], env=env)  # default dry-run
    assert result.returncode == 0
    assert hook.is_symlink(), "dry-run undeploy must not remove anything"


def test_undeploy_skips_append_target(tmp_path, run_dotconfigs):
    """append targets (e.g. ~/.gitconfig) survive undeploy and are reported as
    skipped - they can't be reversed without losing local content."""
    home = tmp_path / "home"
    home.mkdir()
    env = _env(home)
    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0

    gitconfig = home / ".gitconfig"
    assert gitconfig.exists(), "append should have created ~/.gitconfig"
    before = gitconfig.read_text()

    result = run_dotconfigs(["undeploy", "--apply"], env=env)
    assert result.returncode == 0, result.stderr
    assert gitconfig.read_text() == before, "append target must be left untouched"
    assert "not safely reversible" in (result.stdout + result.stderr)


def test_project_undeploy_removes_repo_artefacts(tmp_path, run_dotconfigs):
    """undeploy <path> --apply removes the repo's deployed git-hook symlinks."""
    repo = tmp_path / "repo"
    subprocess.run(
        ["git", "init", "--template=", str(repo)], capture_output=True, check=True
    )
    env = {
        "HOME": str(tmp_path / "home"),
        "DOTCONFIGS_DEPLOY_CONFIG": str(
            tmp_path / "home" / ".dotconfigs" / "deploy.json"
        ),
        "DOTCONFIGS_PROJECT_REGISTRY": str(tmp_path / "reg.list"),
    }
    assert run_dotconfigs(["init", str(repo), "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", str(repo), "--force"], env=env).returncode == 0

    hook = repo / ".git" / "hooks" / "commit-msg"
    assert hook.is_symlink()

    result = run_dotconfigs(["undeploy", str(repo), "--apply"], env=env)
    assert result.returncode == 0, result.stderr
    assert not hook.exists(), (
        "project undeploy should remove the repo's git-hook symlink"
    )
