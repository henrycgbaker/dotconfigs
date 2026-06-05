"""Runtime tests: deploy/cleanup reconcile — sweep dotconfigs-owned orphans,
never touch foreign files or foreign symlinks (the data-loss-risk safety property).
"""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.e2e


def _env(home):
    return {
        "HOME": str(home),
        "DOTCONFIGS_DEPLOY_CONFIG": str(home / ".dotconfigs" / "deploy.json"),
    }


def _deploy_machine(run_dotconfigs, home):
    env = _env(home)
    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0
    return env


def test_deploy_sweeps_catalogue_orphan_keeps_foreign(
    tmp_path, run_dotconfigs, dotconfigs_root
):
    """A deploy is a reconcile (like `stow -R`): a dotconfigs-owned symlink no
    longer in the catalogue is swept, while a foreign file in the same dir
    survives and real catalogued items stay deployed."""
    home = tmp_path / "home"
    home.mkdir()
    env = _deploy_machine(run_dotconfigs, home)

    hooks = home / ".claude" / "hooks"
    orphan = hooks / "zz-removed-hook.sh"  # ours, points into the repo, uncatalogued
    orphan.symlink_to(dotconfigs_root / "plugins/claude/hooks/notify.sh")
    foreign = hooks / "someone-elses.sh"
    foreign.write_text("# not ours\n")

    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0

    assert not orphan.is_symlink(), (
        "orphan dotconfigs symlink should be swept by deploy"
    )
    assert foreign.exists(), "foreign file must be preserved"
    assert (hooks / "notify.sh").is_symlink(), "catalogued hook still deployed"


def test_cleanup_preserves_foreign_and_broken_foreign(
    tmp_path, run_dotconfigs, dotconfigs_root
):
    """cleanup removes dotconfigs-owned stale and broken-into-repo symlinks only;
    foreign files and foreign (broken) symlinks are never touched."""
    home = tmp_path / "home"
    home.mkdir()
    env = _deploy_machine(run_dotconfigs, home)

    hooks = home / ".claude" / "hooks"
    stale = hooks / "zz-stale.sh"  # ours, uncatalogued → removable
    stale.symlink_to(dotconfigs_root / "plugins/claude/hooks/notify.sh")
    foreign_file = hooks / "foreign.sh"
    foreign_file.write_text("# theirs\n")
    foreign_broken = hooks / "foreign-broken.sh"
    foreign_broken.symlink_to("/nowhere/foreign-target")  # broken, NOT into the repo

    result = run_dotconfigs(["cleanup", "--apply"], env=env)
    assert result.returncode == 0, result.stderr

    assert not stale.is_symlink(), "stale dotconfigs-owned symlink removed"
    assert foreign_file.exists(), "foreign file preserved"
    assert foreign_broken.is_symlink(), (
        "foreign broken symlink preserved (not into repo)"
    )


def test_cleanup_dry_run_changes_nothing(tmp_path, run_dotconfigs, dotconfigs_root):
    """Default cleanup is dry-run: it previews but removes nothing."""
    home = tmp_path / "home"
    home.mkdir()
    env = _deploy_machine(run_dotconfigs, home)

    stale = home / ".claude" / "hooks" / "zz-stale.sh"
    stale.symlink_to(dotconfigs_root / "plugins/claude/hooks/notify.sh")

    result = run_dotconfigs(["cleanup"], env=env)  # no --apply
    assert result.returncode == 0
    assert stale.is_symlink(), "dry-run cleanup must not remove anything"
