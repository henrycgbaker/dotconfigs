"""Runtime tests: undeploy removes deployed artefacts without harming foreign files."""

from __future__ import annotations

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
