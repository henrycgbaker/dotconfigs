"""Runtime tests: every deployed hook must be executable.

`os.access(path, os.X_OK)` follows symlinks, so this exercises both the
symlink-resolution path and the underlying file's execute bit.
"""

from __future__ import annotations

import json
import os

import pytest

from tests.runtime.conftest import (
    REPO_ROOT,
    resolve_target,
)


def _expected_hooks(scope: str):
    """Yield (plugin, module_name, target_filename) for every hooks module."""
    for mf in sorted(REPO_ROOT.glob("plugins/*/manifest.json")):
        data = json.loads(mf.read_text())
        plugin = mf.parent.name
        for mod_name, mod_cfg in data.get(scope, {}).items():
            if mod_name != "hooks":
                continue
            include = mod_cfg.get("include", [])
            exclude = mod_cfg.get("exclude", [])
            files = [f for f in include if f not in exclude]
            for filename in files:
                yield plugin, mod_name, filename


@pytest.mark.runtime
class TestGlobalHookExecutable:
    @pytest.mark.parametrize(
        "plugin,mod,filename",
        list(_expected_hooks("global")),
        ids=lambda x: x if isinstance(x, str) else "",
    )
    def test_hook_is_executable(
        self, plugin, mod, filename, deployed_global, dotconfigs_root
    ):
        home, config = deployed_global
        target_dir = resolve_target(
            config[plugin][mod]["target"], home, "global"
        )
        deployed = target_dir / filename
        assert deployed.exists(), f"hook missing: {deployed}"
        assert os.access(deployed, os.X_OK), (
            f"hook is not executable: {deployed} "
            f"(resolves to {deployed.resolve()})"
        )


@pytest.mark.runtime
class TestProjectHookExecutable:
    @pytest.mark.parametrize(
        "plugin,mod,filename",
        list(_expected_hooks("project")),
        ids=lambda x: x if isinstance(x, str) else "",
    )
    def test_hook_is_executable(
        self, plugin, mod, filename, deployed_project, dotconfigs_root
    ):
        project, config = deployed_project
        target_dir = resolve_target(
            config[plugin][mod]["target"], project, "project"
        )
        deployed = target_dir / filename
        assert deployed.exists(), f"hook missing: {deployed}"
        assert os.access(deployed, os.X_OK), (
            f"hook is not executable: {deployed} "
            f"(resolves to {deployed.resolve()})"
        )
