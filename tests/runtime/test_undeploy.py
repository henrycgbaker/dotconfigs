"""Runtime tests: undeploy removes deployed artefacts without harming foreign files."""

from __future__ import annotations

import json

import pytest

from tests.runtime.conftest import (
    read_all_manifests,
    resolve_target,
)


def _deploy_then_undeploy(
    run_dotconfigs, tmp_path_factory, dotconfigs_root, extra_undeploy_args=None
):
    """Helper: deploy to a fresh HOME, then undeploy with given extra args.

    Returns (home, deploy_result, undeploy_result, manifest_config).
    """
    home = tmp_path_factory.mktemp("home")
    deploy_result = run_dotconfigs(
        ["deploy", "--force"], env={"HOME": str(home)}
    )
    assert deploy_result.returncode == 0, deploy_result.stderr

    args = ["undeploy"] + (extra_undeploy_args or ["--apply"])
    undeploy_result = run_dotconfigs(args, env={"HOME": str(home)})
    assert undeploy_result.returncode == 0, undeploy_result.stderr

    config = read_all_manifests(dotconfigs_root, "global")
    return home, deploy_result, undeploy_result, config


@pytest.mark.runtime
class TestGlobalUndeploy:
    """Validate `dotconfigs undeploy --apply` removes our symlinks."""

    def test_symlink_modules_removed(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        home, _, _, config = _deploy_then_undeploy(
            run_dotconfigs, tmp_path_factory, dotconfigs_root
        )

        for plugin, modules in config.items():
            for mod_name, mod_cfg in modules.items():
                if mod_cfg.get("method") != "symlink":
                    continue
                source = dotconfigs_root / mod_cfg["source"]
                target = resolve_target(mod_cfg["target"], home, "global")
                include = mod_cfg.get("include", [])

                if source.is_dir():
                    expected = include if include else [
                        f.name for f in source.iterdir() if f.is_file()
                    ]
                    for filename in expected:
                        file_target = target / filename
                        assert not file_target.is_symlink(), (
                            f"{plugin}/{mod_name}: symlink survived undeploy "
                            f"at {file_target}"
                        )
                else:
                    assert not target.is_symlink(), (
                        f"{plugin}/{mod_name}: symlink survived undeploy at {target}"
                    )

    def test_append_targets_preserved(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        """append-method targets should be left in place (not safely reversible)."""
        home, _, undeploy_result, config = _deploy_then_undeploy(
            run_dotconfigs, tmp_path_factory, dotconfigs_root
        )

        any_append = False
        for plugin, modules in config.items():
            for mod_name, mod_cfg in modules.items():
                if mod_cfg.get("method") != "append":
                    continue
                any_append = True
                target = resolve_target(mod_cfg["target"], home, "global")
                assert target.exists(), (
                    f"{plugin}/{mod_name}: append target was removed: {target}"
                )

        if not any_append:
            pytest.skip("no append modules in global manifest")
        # And the summary should reflect at least one skipped item.
        assert "Skipped:" in undeploy_result.stdout

    def test_dry_run_is_default(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        """`undeploy` without --apply must not remove anything."""
        home = tmp_path_factory.mktemp("home")
        run_dotconfigs(["deploy", "--force"], env={"HOME": str(home)})

        # Pick the first symlink target we can verify
        config = read_all_manifests(dotconfigs_root, "global")
        sample_target = None
        for plugin, modules in config.items():
            for mod_name, mod_cfg in modules.items():
                if mod_cfg.get("method") != "symlink":
                    continue
                source = dotconfigs_root / mod_cfg["source"]
                target = resolve_target(mod_cfg["target"], home, "global")
                if source.is_dir():
                    include = mod_cfg.get("include", [])
                    if include:
                        sample_target = target / include[0]
                        break
                else:
                    sample_target = target
                    break
            if sample_target is not None:
                break
        assert sample_target is not None and sample_target.is_symlink()

        result = run_dotconfigs(["undeploy"], env={"HOME": str(home)})
        assert result.returncode == 0
        assert sample_target.is_symlink(), (
            "dry-run undeploy removed a symlink it shouldn't have"
        )
        assert "Would remove" in result.stdout or "Dry-run" in result.stdout

    def test_foreign_file_preserved(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        """A foreign file in a managed directory must survive undeploy."""
        home = tmp_path_factory.mktemp("home")
        run_dotconfigs(["deploy", "--force"], env={"HOME": str(home)})

        # Drop a foreign file into ~/.claude/hooks (a directory module target)
        hooks_dir = home / ".claude" / "hooks"
        assert hooks_dir.is_dir()
        foreign = hooks_dir / "foreign-tool.sh"
        foreign.write_text("# foreign\n")

        result = run_dotconfigs(["undeploy", "--apply"], env={"HOME": str(home)})
        assert result.returncode == 0
        assert foreign.exists(), "foreign file was removed by undeploy"
        assert foreign.read_text() == "# foreign\n"


@pytest.mark.runtime
class TestUndeployGroupFilter:
    def test_group_filter_only_undeploys_one_plugin(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        home = tmp_path_factory.mktemp("home")
        run_dotconfigs(["deploy", "--force"], env={"HOME": str(home)})

        # Undeploy only the shell group
        result = run_dotconfigs(
            ["undeploy", "shell", "--apply"], env={"HOME": str(home)}
        )
        assert result.returncode == 0

        # Shell symlinks should be gone …
        shell_target = home / ".dotconfigs" / "shell" / "init.zsh"
        assert not shell_target.is_symlink()

        # … but claude hooks should still be in place.
        claude_hooks = home / ".claude" / "hooks"
        survivors = [p for p in claude_hooks.iterdir() if p.is_symlink()]
        assert survivors, "claude symlinks were undeployed despite group filter"


@pytest.mark.runtime
class TestProjectUndeploy:
    def test_project_undeploy_removes_hooks(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        import subprocess

        project = tmp_path_factory.mktemp("project")
        subprocess.run(["git", "init", str(project)], capture_output=True, check=True)

        run_dotconfigs(["project-init", str(project)])
        run_dotconfigs(["project", str(project), "--force"])

        # Confirm some project hooks exist as symlinks first
        git_hooks = project / ".git" / "hooks"
        live = [p for p in git_hooks.iterdir() if p.is_symlink()]
        assert live, "project deploy did not create any symlinks"

        result = run_dotconfigs(
            ["undeploy", "--project", str(project), "--apply"]
        )
        assert result.returncode == 0

        surviving = [p for p in git_hooks.iterdir() if p.is_symlink()]
        assert not surviving, (
            f"project undeploy left symlinks behind: {surviving}"
        )
