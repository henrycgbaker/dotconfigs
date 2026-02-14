"""Runtime tests: global deploy produces correct filesystem state.

Expectations are derived from plugin manifests (SSOT). Adding a new
plugin or module automatically extends these tests.
"""

from __future__ import annotations

import json

import pytest

from tests.runtime.conftest import (
    REPO_ROOT,
    read_all_manifests,
    resolve_target,
    validate_module,
)


# ---------------------------------------------------------------------------
# Parametrize helpers (run at collection time)
# ---------------------------------------------------------------------------


def _global_module_ids() -> list[str]:
    """Return plugin/module IDs for all global modules across all plugins."""
    ids = []
    for mf in sorted(REPO_ROOT.glob("plugins/*/manifest.json")):
        data = json.loads(mf.read_text())
        plugin = mf.parent.name
        for mod_name in data.get("global", {}):
            ids.append(f"{plugin}/{mod_name}")
    return ids


# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------


@pytest.mark.runtime
class TestGlobalDeploy:
    """Validate that `dotconfigs deploy` creates correct targets for all global modules."""

    @pytest.mark.parametrize("module_path", _global_module_ids())
    def test_module_deployed(self, module_path, deployed_global, dotconfigs_root):
        """Each global module's files exist at correct targets with correct type."""
        home, config = deployed_global
        plugin, mod_name = module_path.split("/")
        mod_config = config[plugin][mod_name]

        failures = validate_module(mod_config, dotconfigs_root, home, scope="global")
        assert not failures, "\n".join(failures)

    def test_all_plugins_represented(self, deployed_global):
        """Every plugin with a .global manifest section has deployed modules."""
        _, config = deployed_global
        manifests = read_all_manifests(REPO_ROOT, "global")
        assert set(config.keys()) == set(manifests.keys()), (
            f"Plugin mismatch: deployed={set(config.keys())}, "
            f"manifests={set(manifests.keys())}"
        )

    def test_global_json_matches_manifests(self, dotconfigs_root):
        """global.json accurately reflects manifest .global sections (SSOT check)."""
        global_json_path = dotconfigs_root / ".dotconfigs" / "global.json"
        if not global_json_path.exists():
            pytest.skip("global.json not present (run global-init)")

        global_config = json.loads(global_json_path.read_text())
        manifest_config = read_all_manifests(dotconfigs_root, "global")

        # Compare plugin sets
        assert set(global_config.keys()) == set(manifest_config.keys()), (
            f"Plugin mismatch: global.json={set(global_config.keys())}, "
            f"manifests={set(manifest_config.keys())}"
        )

        # Compare module sets per plugin
        for plugin in manifest_config:
            global_modules = set(global_config[plugin].keys())
            manifest_modules = set(manifest_config[plugin].keys())
            assert global_modules == manifest_modules, (
                f"{plugin}: module mismatch: "
                f"global.json={global_modules}, manifest={manifest_modules}"
            )

            # Compare include lists per module
            for mod_name in manifest_config[plugin]:
                gm = global_config[plugin][mod_name]
                mm = manifest_config[plugin][mod_name]
                g_include = sorted(gm.get("include", []))
                m_include = sorted(mm.get("include", []))
                assert g_include == m_include, (
                    f"{plugin}/{mod_name}: include mismatch: "
                    f"global.json={g_include}, manifest={m_include}"
                )

    def test_symlinks_point_to_repo(self, deployed_global, dotconfigs_root):
        """All symlinks resolve to files within the dotconfigs repo."""
        home, config = deployed_global
        for plugin, modules in config.items():
            for mod_name, mod_config in modules.items():
                if mod_config["method"] != "symlink":
                    continue

                source = dotconfigs_root / mod_config["source"]
                target = resolve_target(mod_config["target"], home, "global")

                if source.is_dir():
                    include = mod_config.get("include", [])
                    files = (
                        include
                        if include
                        else [f.name for f in source.iterdir() if f.is_file()]
                    )
                    for f in files:
                        ft = target / f
                        if ft.is_symlink():
                            resolved = ft.resolve()
                            assert str(resolved).startswith(str(dotconfigs_root)), (
                                f"{ft} -> {resolved} (outside repo)"
                            )
                else:
                    if target.is_symlink():
                        resolved = target.resolve()
                        assert str(resolved).startswith(str(dotconfigs_root)), (
                            f"{target} -> {resolved} (outside repo)"
                        )
