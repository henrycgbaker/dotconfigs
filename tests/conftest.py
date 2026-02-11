"""Shared fixtures and helpers for dotconfigs tests."""

from __future__ import annotations

import json
import os
import subprocess
from dataclasses import dataclass
from pathlib import Path

import pytest


@dataclass
class BashResult:
    returncode: int
    stdout: str
    stderr: str


def run_bash(
    script: str,
    cwd: str | Path | None = None,
    env: dict[str, str] | None = None,
    timeout: int = 30,
) -> BashResult:
    """Run a bash snippet and return structured result."""
    merged_env = {**os.environ, **(env or {})}
    result = subprocess.run(
        ["bash", "-c", script],
        capture_output=True,
        text=True,
        cwd=cwd,
        env=merged_env,
        timeout=timeout,
    )
    return BashResult(result.returncode, result.stdout, result.stderr)


def run_bash_function(
    dotconfigs_root: Path,
    lib_file: str,
    function_name: str,
    args: list[str] | None = None,
    env: dict[str, str] | None = None,
) -> BashResult:
    """Source libs and call a single bash function."""
    args_str = " ".join(f'"{a}"' for a in (args or []))
    script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
{function_name} {args_str}
"""
    return run_bash(script, cwd=dotconfigs_root, env=env)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------


@pytest.fixture(scope="session")
def dotconfigs_root() -> Path:
    """Real repo root (read-only)."""
    root = Path(__file__).resolve().parent.parent
    assert (root / "dotconfigs").exists(), "Cannot find dotconfigs entry point"
    return root


@pytest.fixture()
def project_dir(tmp_path: Path) -> Path:
    """Temporary git-initialised directory."""
    subprocess.run(["git", "init", str(tmp_path)], capture_output=True, check=True)
    return tmp_path


@pytest.fixture()
def make_json_config(tmp_path: Path):
    """Factory: write a JSON config to tmp_path and return path."""

    def _make(data: dict, filename: str = "config.json") -> Path:
        p = tmp_path / filename
        p.write_text(json.dumps(data, indent=2))
        return p

    return _make


@pytest.fixture()
def fake_source_tree(tmp_path: Path):
    """Create plugin-like source directories with dummy files.

    Returns the root directory containing the fake plugin tree.
    """

    def _make(
        plugins: dict[str, dict[str, list[str]]] | None = None,
    ) -> Path:
        root = tmp_path / "fakerepo"
        root.mkdir(exist_ok=True)
        # Create a sentinel so bash can detect the "dotconfigs root"
        (root / "dotconfigs").touch()

        plugins = plugins or {
            "claude": {"hooks": ["block-destructive.sh", "post-tool-format.py"]},
            "git": {"hooks": ["pre-commit", "prepare-commit-msg"]},
        }
        for plugin, groups in plugins.items():
            for group, files in groups.items():
                d = root / "plugins" / plugin / group
                d.mkdir(parents=True, exist_ok=True)
                for f in files:
                    (d / f).write_text(f"# stub {f}\n")
        return root

    return _make


@pytest.fixture(scope="session")
def run_dotconfigs(dotconfigs_root: Path):
    """Run the real dotconfigs CLI entry point."""

    def _run(
        args: list[str] | None = None,
        cwd: str | Path | None = None,
        env: dict[str, str] | None = None,
    ) -> BashResult:
        cli = str(dotconfigs_root / "dotconfigs")
        cmd_args = " ".join(f'"{a}"' for a in (args or []))
        return run_bash(f'"{cli}" {cmd_args}', cwd=cwd, env=env)

    return _run
