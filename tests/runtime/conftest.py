"""Shared fixtures and validation helpers for runtime integration tests.

These tests validate that dotconfigs deploy actually produces correct
filesystem state. Expectations are derived from plugin manifests (SSOT),
not hardcoded — adding a new plugin or module automatically extends tests.
"""

from __future__ import annotations

import json
import subprocess
from pathlib import Path

import pytest


# ---------------------------------------------------------------------------
# Helpers (importable by test modules)
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parents[2]


def read_all_manifests(repo_root: Path, scope: str) -> dict:
    """Read all plugin manifests and merge their scope sections.

    Returns dict keyed by plugin name, e.g.:
        {"claude": {"hooks": {...}, "skills": {...}}, "git": {"hooks": {...}}}
    """
    config: dict = {}
    for manifest_path in sorted(repo_root.glob("plugins/*/manifest.json")):
        plugin_name = manifest_path.parent.name
        manifest = json.loads(manifest_path.read_text())
        if scope in manifest:
            config[plugin_name] = manifest[scope]
    return config


def resolve_target(target_str: str, deploy_root: Path, scope: str) -> Path:
    """Resolve a target path to an absolute path.

    For global scope: expand ~ to deploy_root (mock HOME).
    For project scope: prepend deploy_root (project dir).
    """
    if scope == "global":
        return Path(target_str.replace("~", str(deploy_root)))
    return deploy_root / target_str


def validate_module(
    mod_config: dict,
    repo_root: Path,
    deploy_root: Path,
    scope: str,
) -> list[str]:
    """Validate a single deployed module. Returns list of failure messages."""
    failures: list[str] = []
    source = repo_root / mod_config["source"]
    target = resolve_target(mod_config["target"], deploy_root, scope)
    method = mod_config["method"]
    include = mod_config.get("include", [])
    exclude = mod_config.get("exclude", [])

    if source.is_dir():
        effective = [f for f in include if f not in exclude] if include else []
        if not effective and not include:
            # No include list = all files in source directory
            effective = [f.name for f in source.iterdir() if f.is_file()]

        for filename in effective:
            file_source = source / filename
            file_target = target / filename

            if not file_source.exists():
                failures.append(f"Source missing: {file_source}")
                continue

            if not file_target.exists():
                failures.append(f"Target missing: {file_target}")
                continue

            if method == "symlink":
                if not file_target.is_symlink():
                    failures.append(f"Not a symlink: {file_target}")
                elif file_target.resolve() != file_source.resolve():
                    failures.append(
                        f"Symlink target mismatch: {file_target} -> "
                        f"{file_target.resolve()}, expected {file_source.resolve()}"
                    )
            elif method == "copy":
                if file_target.read_text() != file_source.read_text():
                    failures.append(f"Content mismatch: {file_target}")
    else:
        # Single file module
        if not source.exists():
            failures.append(f"Source missing: {source}")
        elif not target.exists():
            failures.append(f"Target missing: {target}")
        elif method == "symlink":
            if not target.is_symlink():
                failures.append(f"Not a symlink: {target}")
            elif target.resolve() != source.resolve():
                failures.append(
                    f"Symlink target mismatch: {target} -> "
                    f"{target.resolve()}, expected {source.resolve()}"
                )
        elif method == "copy":
            if target.read_text() != source.read_text():
                failures.append(f"Content mismatch: {target}")

    return failures


def ensure_global_json(repo_root: Path) -> Path:
    """Ensure global.json exists, assembling from manifests if needed."""
    global_json = repo_root / ".dotconfigs" / "global.json"
    if not global_json.exists():
        global_json.parent.mkdir(parents=True, exist_ok=True)
        config = read_all_manifests(repo_root, "global")
        global_json.write_text(json.dumps(config, indent=2) + "\n")
    return global_json


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="module")
def deployed_global(tmp_path_factory, dotconfigs_root, run_dotconfigs):
    """Deploy global configs to a temp HOME directory.

    Returns (home_path, manifest_config) tuple.
    """
    home = tmp_path_factory.mktemp("home")

    # Ensure global.json exists (gitignored, might be absent on fresh clone)
    ensure_global_json(dotconfigs_root)

    result = run_dotconfigs(
        ["deploy", "--force"],
        env={"HOME": str(home)},
    )
    assert result.returncode == 0, (
        f"deploy failed (rc={result.returncode}):\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    )

    config = read_all_manifests(dotconfigs_root, "global")
    return home, config


@pytest.fixture(scope="module")
def deployed_project(tmp_path_factory, dotconfigs_root, run_dotconfigs):
    """Create a temp git repo, project-init, and project deploy.

    Returns (project_path, manifest_config) tuple.
    """
    project = tmp_path_factory.mktemp("project")
    subprocess.run(
        ["git", "init", str(project)],
        capture_output=True,
        check=True,
    )

    # project-init (no TTY prompt for fresh dir — project.json doesn't exist yet)
    result = run_dotconfigs(["project-init", str(project)])
    assert result.returncode == 0, (
        f"project-init failed (rc={result.returncode}):\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    )

    # project deploy
    result = run_dotconfigs(["project", str(project), "--force"])
    assert result.returncode == 0, (
        f"project deploy failed (rc={result.returncode}):\n"
        f"stdout: {result.stdout}\nstderr: {result.stderr}"
    )

    config = read_all_manifests(dotconfigs_root, "project")
    return project, config
