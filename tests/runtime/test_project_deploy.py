"""Runtime tests: project deploy produces correct filesystem state.

Expectations are derived from plugin manifests (SSOT). Adding a new
plugin or module automatically extends these tests.
"""

from __future__ import annotations

import json
import subprocess

import pytest

from tests.runtime.conftest import (
    REPO_ROOT,
    read_all_manifests,
    validate_module,
)


# ---------------------------------------------------------------------------
# Parametrize helpers (run at collection time)
# ---------------------------------------------------------------------------


def _project_module_ids() -> list[str]:
    """Return plugin/module IDs for all project modules across all plugins."""
    ids = []
    for mf in sorted(REPO_ROOT.glob("plugins/*/manifest.json")):
        data = json.loads(mf.read_text())
        plugin = mf.parent.name
        for mod_name in data.get("project", {}):
            ids.append(f"{plugin}/{mod_name}")
    return ids


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.runtime
class TestProjectDeploy:
    """Validate that project-init + project deploy creates correct targets."""

    @pytest.mark.parametrize("module_path", _project_module_ids())
    def test_module_deployed(self, module_path, deployed_project, dotconfigs_root):
        """Each project module's files exist at correct targets with correct type."""
        project, config = deployed_project
        plugin, mod_name = module_path.split("/")
        mod_config = config[plugin][mod_name]

        failures = validate_module(
            mod_config, dotconfigs_root, project, scope="project"
        )
        assert not failures, "\n".join(failures)

    def test_all_plugins_represented(self, deployed_project):
        """Every plugin with a .project manifest section has deployed modules."""
        _, config = deployed_project
        manifests = read_all_manifests(REPO_ROOT, "project")
        assert set(config.keys()) == set(manifests.keys()), (
            f"Plugin mismatch: deployed={set(config.keys())}, "
            f"manifests={set(manifests.keys())}"
        )

    def test_project_json_created(self, deployed_project):
        """project-init creates .dotconfigs/project.json."""
        project, _ = deployed_project
        pj = project / ".dotconfigs" / "project.json"
        assert pj.exists(), f"Missing: {pj}"
        data = json.loads(pj.read_text())
        assert isinstance(data, dict)
        assert len(data) > 0

    def test_project_json_matches_manifests(self, deployed_project, dotconfigs_root):
        """project.json include lists match manifest .project sections."""
        project, _ = deployed_project
        pj = project / ".dotconfigs" / "project.json"
        project_config = json.loads(pj.read_text())
        manifest_config = read_all_manifests(dotconfigs_root, "project")

        for plugin in manifest_config:
            assert plugin in project_config, (
                f"Plugin {plugin} missing from project.json"
            )
            for mod_name, mod_manifest in manifest_config[plugin].items():
                assert mod_name in project_config[plugin], (
                    f"{plugin}/{mod_name} missing from project.json"
                )
                m_include = sorted(mod_manifest.get("include", []))
                p_include = sorted(project_config[plugin][mod_name].get("include", []))
                assert p_include == m_include, (
                    f"{plugin}/{mod_name}: include mismatch: "
                    f"project.json={p_include}, manifest={m_include}"
                )

    def test_dotconfigs_excluded(self, deployed_project):
        """.dotconfigs/ is in .git/info/exclude after project-init."""
        project, _ = deployed_project
        exclude_file = project / ".git" / "info" / "exclude"
        assert exclude_file.exists(), f"Missing: {exclude_file}"
        content = exclude_file.read_text()
        assert ".dotconfigs/" in content or ".dotconfigs" in content

    def test_symlinks_point_to_repo(self, deployed_project, dotconfigs_root):
        """All project symlinks resolve to files within the dotconfigs repo."""
        project, config = deployed_project
        for plugin, modules in config.items():
            for mod_name, mod_config in modules.items():
                if mod_config["method"] != "symlink":
                    continue

                source = dotconfigs_root / mod_config["source"]
                target = project / mod_config["target"]
                include = mod_config.get("include", [])
                exclude = mod_config.get("exclude", [])
                effective = [f for f in include if f not in exclude] if include else []

                if source.is_dir() and effective:
                    for f in effective:
                        ft = target / f
                        if ft.is_symlink():
                            resolved = ft.resolve()
                            assert str(resolved).startswith(str(dotconfigs_root)), (
                                f"{ft} -> {resolved} (outside repo)"
                            )
                elif not source.is_dir() and target.is_symlink():
                    resolved = target.resolve()
                    assert str(resolved).startswith(str(dotconfigs_root)), (
                        f"{target} -> {resolved} (outside repo)"
                    )


@pytest.mark.runtime
class TestProjectExcludeMechanism:
    """Validate that exclude lists in project.json prevent deployment."""

    def test_exclude_prevents_deployment(
        self, tmp_path, dotconfigs_root, run_dotconfigs
    ):
        """Excluding a file from project.json removes it from deployment."""
        project = tmp_path / "exclude_test"
        project.mkdir()
        subprocess.run(["git", "init", str(project)], capture_output=True, check=True)

        # Init project
        result = run_dotconfigs(["project-init", str(project)])
        assert result.returncode == 0

        # Find a module with include list to test exclude against
        manifests = read_all_manifests(dotconfigs_root, "project")
        target_plugin = None
        target_module = None
        target_file = None

        for plugin, modules in manifests.items():
            for mod_name, mod_config in modules.items():
                include = mod_config.get("include", [])
                if len(include) >= 2:
                    target_plugin = plugin
                    target_module = mod_name
                    target_file = include[0]
                    break
            if target_file:
                break

        if not target_file:
            pytest.skip("No module with 2+ include files to test exclude")

        # Modify project.json to exclude one file
        pj_path = project / ".dotconfigs" / "project.json"
        pj = json.loads(pj_path.read_text())
        pj[target_plugin][target_module]["exclude"] = [target_file]
        pj_path.write_text(json.dumps(pj, indent=2))

        # Deploy
        result = run_dotconfigs(["project", str(project), "--force"])
        assert result.returncode == 0

        # Verify excluded file was NOT deployed
        target_dir = project / manifests[target_plugin][target_module]["target"]
        excluded_path = target_dir / target_file
        assert not excluded_path.exists(), (
            f"Excluded file was deployed: {excluded_path}"
        )

        # Verify other files in include list WERE deployed
        include_list = manifests[target_plugin][target_module]["include"]
        for f in include_list:
            if f != target_file:
                assert (target_dir / f).exists(), (
                    f"Non-excluded file missing: {target_dir / f}"
                )
