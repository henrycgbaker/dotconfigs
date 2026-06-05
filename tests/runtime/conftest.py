"""Shared fixtures and validation helpers for runtime integration tests.

These tests validate that `dotconfigs deploy` actually produces correct
filesystem state. Expectations are derived from the plugin catalogues
(manifest.json, the SSOT) — adding a plugin or item automatically extends them.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest

REPO_ROOT = Path(__file__).resolve().parents[2]


def _is_machine_target(t: str) -> bool:
    return t.startswith("~") or t.startswith("/")


def catalogue_items(repo_root: Path, scope: str) -> list[dict]:
    """Flatten every plugin manifest into per-item dicts for a scope.

    Each item: {label, plugin, category, name, source, method, default, targets}
    where targets are only those matching the scope (machine: ~/absolute,
    project: relative).
    """
    items: list[dict] = []
    for manifest_path in sorted(repo_root.glob("plugins/*/manifest.json")):
        plugin = manifest_path.parent.name
        manifest = json.loads(manifest_path.read_text())
        for category, entries in manifest.items():
            for name, e in entries.items():
                targets = e["target"]
                if isinstance(targets, str):
                    targets = [targets]
                scoped = [
                    t
                    for t in targets
                    if (
                        _is_machine_target(t)
                        if scope == "machine"
                        else not _is_machine_target(t)
                    )
                ]
                if not scoped:
                    continue
                items.append(
                    {
                        "label": f"{plugin}/{category}/{name}",
                        "plugin": plugin,
                        "category": category,
                        "name": name,
                        "source": e["source"],
                        "method": e["method"],
                        "default": e.get("default", False),
                        "targets": scoped,
                    }
                )
    return items


def resolve_target(target: str, deploy_root: Path, scope: str) -> Path:
    """machine: ~ -> deploy_root (mock HOME). project: prepend deploy_root (repo)."""
    if scope == "machine":
        return Path(target.replace("~", str(deploy_root), 1))
    return deploy_root / target


def validate_item(
    item: dict, repo_root: Path, deploy_root: Path, scope: str
) -> list[str]:
    """Validate one deployed item across its scope targets. Returns failures."""
    failures: list[str] = []
    source = repo_root / item["source"]
    method = item["method"]
    if not source.exists():
        return [f"Source missing: {source}"]

    for tstr in item["targets"]:
        target = resolve_target(tstr, deploy_root, scope)
        if not target.exists() and not target.is_symlink():
            failures.append(f"Target missing: {target}")
            continue
        if method == "symlink":
            if not target.is_symlink():
                failures.append(f"Not a symlink: {target}")
            elif target.resolve() != source.resolve():
                failures.append(f"Symlink mismatch: {target} -> {target.resolve()}")
        elif method == "merge":
            if target.is_symlink():
                failures.append(f"Merge target is a symlink: {target}")
            else:
                try:
                    s_allow = set(
                        json.loads(source.read_text())
                        .get("permissions", {})
                        .get("allow", [])
                    )
                    t_allow = set(
                        json.loads(target.read_text())
                        .get("permissions", {})
                        .get("allow", [])
                    )
                    if not s_allow <= t_allow:
                        failures.append(f"Merge dropped base permissions: {target}")
                except json.JSONDecodeError:
                    failures.append(f"Merge target not valid JSON: {target}")
        elif method == "append":
            if target.is_symlink():
                failures.append(f"Append target is a symlink: {target}")
            else:
                text = target.read_text()
                missing = [
                    ln
                    for ln in source.read_text().splitlines()
                    if ln.strip() and ln not in text
                ]
                if missing:
                    failures.append(
                        f"Append missing lines: {target} (first: {missing[0]!r})"
                    )
        elif method == "managed":
            if target.is_symlink():
                failures.append(f"Managed target is a symlink: {target}")
            else:
                text = target.read_text()
                if "# >>> dotconfigs:" not in text:
                    failures.append(f"Managed target missing sentinel: {target}")
    return failures


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def deployed_machine(tmp_path_factory, dotconfigs_root, run_dotconfigs):
    """init + deploy the machine selection into a temp HOME. Returns home path."""
    home = tmp_path_factory.mktemp("home")
    deploy_json = home / ".dotconfigs" / "deploy.json"
    env = {"HOME": str(home), "DOTCONFIGS_DEPLOY_CONFIG": str(deploy_json)}

    result = run_dotconfigs(["init", "--force"], env=env)
    assert result.returncode == 0, f"init failed:\n{result.stdout}\n{result.stderr}"
    result = run_dotconfigs(["deploy", "--force"], env=env)
    assert result.returncode == 0, f"deploy failed:\n{result.stdout}\n{result.stderr}"
    return home


@pytest.fixture(scope="module")
def deployed_project(tmp_path_factory, dotconfigs_root, run_dotconfigs):
    """init + deploy a project selection into a temp git repo. Returns repo path."""
    project = tmp_path_factory.mktemp("project")
    subprocess.run(["git", "init", str(project)], capture_output=True, check=True)

    result = run_dotconfigs(["init", str(project), "--force"])
    assert result.returncode == 0, f"init failed:\n{result.stdout}\n{result.stderr}"
    result = run_dotconfigs(["deploy", str(project), "--force"])
    assert result.returncode == 0, f"deploy failed:\n{result.stdout}\n{result.stderr}"
    return project
