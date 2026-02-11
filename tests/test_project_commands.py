"""E2E tests for project-init and project deploy commands."""

from __future__ import annotations

import json

import pytest

pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# project-init — SSOT from plugin manifests
# ---------------------------------------------------------------------------


class TestProjectInitSSOT:
    """project-init generates project.json from manifest .project sections."""

    def test_include_lists_match_manifests(
        self, run_dotconfigs, project_dir, dotconfigs_root
    ):
        """Include lists in project.json must match manifest .project section."""
        result = run_dotconfigs(["project-init", str(project_dir)])
        assert result.returncode == 0

        project_json = project_dir / ".dotconfigs" / "project.json"
        assert project_json.exists()
        project = json.loads(project_json.read_text())

        # Claude hooks/skills must match manifest's project section
        claude_manifest = json.loads(
            (dotconfigs_root / "plugins/claude/manifest.json").read_text()
        )
        assert (
            project["claude"]["hooks"]["include"]
            == claude_manifest["project"]["hooks"]["include"]
        )
        assert (
            project["claude"]["skills"]["include"]
            == claude_manifest["project"]["skills"]["include"]
        )

        # Git hooks must match manifest's project section
        git_manifest = json.loads(
            (dotconfigs_root / "plugins/git/manifest.json").read_text()
        )
        assert (
            project["git"]["hooks"]["include"]
            == git_manifest["project"]["hooks"]["include"]
        )

    @pytest.mark.parametrize(
        "plugin,group",
        [("claude", "hooks"), ("git", "hooks")],
    )
    def test_exclude_empty_on_hooks(self, run_dotconfigs, project_dir, plugin, group):
        """Hooks modules have exclude: [] for user customisation."""
        run_dotconfigs(["project-init", str(project_dir)])
        project_json = project_dir / ".dotconfigs" / "project.json"
        project = json.loads(project_json.read_text())
        assert project[plugin][group]["exclude"] == []

    def test_targets_are_project_relative(self, run_dotconfigs, project_dir):
        """Targets should not contain ~ (they're project-relative)."""
        run_dotconfigs(["project-init", str(project_dir)])
        project_json = project_dir / ".dotconfigs" / "project.json"
        content = project_json.read_text()
        # Walk all target values — none should have tilde
        project = json.loads(content)
        for plugin_data in project.values():
            for module_data in plugin_data.values():
                if isinstance(module_data, dict) and "target" in module_data:
                    assert "~" not in module_data["target"], (
                        f"Target contains ~: {module_data['target']}"
                    )

    def test_source_paths_match_manifests(
        self, run_dotconfigs, project_dir, dotconfigs_root
    ):
        """Source paths should match manifest .project section."""
        run_dotconfigs(["project-init", str(project_dir)])
        project_json = project_dir / ".dotconfigs" / "project.json"
        project = json.loads(project_json.read_text())

        claude_manifest = json.loads(
            (dotconfigs_root / "plugins/claude/manifest.json").read_text()
        )
        assert (
            project["claude"]["hooks"]["source"]
            == claude_manifest["project"]["hooks"]["source"]
        )

        git_manifest = json.loads(
            (dotconfigs_root / "plugins/git/manifest.json").read_text()
        )
        assert (
            project["git"]["hooks"]["source"]
            == git_manifest["project"]["hooks"]["source"]
        )


# ---------------------------------------------------------------------------
# project-init — UX behaviour
# ---------------------------------------------------------------------------


class TestProjectInitUX:
    """project-init UX: directory creation, idempotency, error cases."""

    def test_creates_dotconfigs_directory(self, run_dotconfigs, project_dir):
        run_dotconfigs(["project-init", str(project_dir)])
        assert (project_dir / ".dotconfigs").is_dir()
        assert (project_dir / ".dotconfigs" / "project.json").exists()

    def test_idempotent_no_overwrite(self, run_dotconfigs, project_dir):
        """Second run does not overwrite existing project.json."""
        run_dotconfigs(["project-init", str(project_dir)])
        first_content = (project_dir / ".dotconfigs" / "project.json").read_text()

        result = run_dotconfigs(["project-init", str(project_dir)])
        assert result.returncode == 0
        assert "already exists" in result.stdout
        assert (
            project_dir / ".dotconfigs" / "project.json"
        ).read_text() == first_content

    def test_errors_on_non_git_directory(self, run_dotconfigs, tmp_path):
        """Non-git directory should produce an error."""
        plain_dir = tmp_path / "not_a_repo"
        plain_dir.mkdir()
        result = run_dotconfigs(["project-init", str(plain_dir)])
        assert result.returncode != 0
        assert "git" in result.stderr.lower() or "git" in result.stdout.lower()

    def test_auto_excludes_dotconfigs_in_git_info(self, run_dotconfigs, project_dir):
        """project-init adds .dotconfigs/ to .git/info/exclude."""
        run_dotconfigs(["project-init", str(project_dir)])
        exclude_file = project_dir / ".git" / "info" / "exclude"
        assert exclude_file.exists()
        assert ".dotconfigs/" in exclude_file.read_text()

    def test_defaults_to_cwd(self, run_dotconfigs, project_dir):
        """project-init with no args uses CWD."""
        result = run_dotconfigs([], cwd=project_dir)
        # Just running with no args shows usage — we need project-init specifically
        result = run_dotconfigs(["project-init"], cwd=project_dir)
        assert result.returncode == 0
        assert (project_dir / ".dotconfigs" / "project.json").exists()


# ---------------------------------------------------------------------------
# project init (space-separated) routing
# ---------------------------------------------------------------------------


def test_project_init_space_routing(run_dotconfigs, project_dir):
    """'dotconfigs project init <dir>' should behave like 'dotconfigs project-init <dir>'."""
    result = run_dotconfigs(["project", "init", str(project_dir)])
    assert result.returncode == 0
    assert (project_dir / ".dotconfigs" / "project.json").exists()


# ---------------------------------------------------------------------------
# project deploy — exclude mechanism
# ---------------------------------------------------------------------------


class TestProjectDeployExclude:
    """project deploy respects the exclude list in project.json."""

    @pytest.mark.parametrize(
        "exclude,deployed,absent",
        [
            ([], ["block-destructive.sh", "post-tool-format.py"], []),
            (
                ["post-tool-format.py"],
                ["block-destructive.sh"],
                ["post-tool-format.py"],
            ),
            (
                ["block-destructive.sh", "post-tool-format.py"],
                [],
                ["block-destructive.sh", "post-tool-format.py"],
            ),
        ],
        ids=["no-exclude", "exclude-one", "exclude-all"],
    )
    def test_exclude_mechanism(
        self,
        run_dotconfigs,
        project_dir,
        dotconfigs_root,
        exclude,
        deployed,
        absent,
    ):
        """project-init, patch exclude, project deploy, check filesystem."""
        # Step 1: project-init
        result = run_dotconfigs(["project-init", str(project_dir)])
        assert result.returncode == 0

        # Step 2: patch the exclude list for claude hooks
        config_file = project_dir / ".dotconfigs" / "project.json"
        config = json.loads(config_file.read_text())
        config["claude"]["hooks"]["exclude"] = exclude
        config_file.write_text(json.dumps(config, indent=2))

        # Step 3: project deploy
        result = run_dotconfigs(["project", str(project_dir), "--force"])
        assert result.returncode == 0

        # Step 4: verify filesystem
        hooks_dir = project_dir / ".claude" / "hooks"
        for f in deployed:
            assert (hooks_dir / f).exists(), f"Expected {f} to be deployed"
        for f in absent:
            assert not (hooks_dir / f).exists(), f"Expected {f} to NOT be deployed"


# ---------------------------------------------------------------------------
# project deploy — UX
# ---------------------------------------------------------------------------


class TestProjectDeployUX:
    """project deploy UX: symlinks, CWD default, dry-run, error cases."""

    def test_creates_symlinks(self, run_dotconfigs, project_dir, dotconfigs_root):
        run_dotconfigs(["project-init", str(project_dir)])
        result = run_dotconfigs(["project", str(project_dir), "--force"])
        assert result.returncode == 0

        hooks_dir = project_dir / ".claude" / "hooks"
        for f in hooks_dir.iterdir():
            assert f.is_symlink()
            target = f.resolve()
            assert str(dotconfigs_root) in str(target)

    def test_dry_run_creates_nothing(self, run_dotconfigs, project_dir):
        run_dotconfigs(["project-init", str(project_dir)])
        result = run_dotconfigs(["project", str(project_dir), "--dry-run"])
        assert result.returncode == 0
        assert "Dry-run" in result.stdout or "Would link" in result.stdout
        # Hooks directory should not exist (only .dotconfigs was created by init)
        assert not (project_dir / ".claude" / "hooks").exists()

    def test_error_when_no_project_json(self, run_dotconfigs, project_dir):
        """project deploy without project.json should error."""
        result = run_dotconfigs(["project", str(project_dir)])
        assert result.returncode != 0
        assert "project.json" in result.stderr or "project-init" in result.stderr

    def test_defaults_to_cwd(self, run_dotconfigs, project_dir):
        """project with no path argument uses CWD."""
        run_dotconfigs(["project-init", str(project_dir)])
        result = run_dotconfigs(["project", "--force"], cwd=project_dir)
        assert result.returncode == 0
        assert (project_dir / ".claude" / "hooks").exists()
