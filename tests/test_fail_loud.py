"""Tests for the fail-loud cluster: refcheck.sh, merge-collision warnings,
deploy source-missing errors, and the `dotconfigs validate` subcommand."""

from __future__ import annotations

import json
import shutil
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit


def _source(root: Path, *libs: str) -> str:
    return "\n".join(f'source "{root}/lib/{lib}"' for lib in libs)


# ---------------------------------------------------------------------------
# refcheck_resolve_path
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "ref,base,expected",
    [
        ("/abs/path/x.sh", "/base", "/abs/path/x.sh"),
        ("~/x.sh", "/base", "{HOME}/x.sh"),
        ("./rel.sh", "/base", "/base/rel.sh"),
        ("sub/rel.sh", "/base", "/base/sub/rel.sh"),
        ("barecmd", "/base", ""),  # PATH-style name → not file-checked
        ("${CLAUDE_PROJECT_DIR}/h.sh", "/base", "/base/h.sh"),
        ("$CLAUDE_PROJECT_DIR/h.sh", "/base", "/base/h.sh"),
        ("/abs/x.sh --flag arg", "/base", "/abs/x.sh"),  # args stripped
    ],
    ids=[
        "absolute",
        "tilde",
        "dot-relative",
        "relative-with-slash",
        "bare-name",
        "project-dir-braced",
        "project-dir-bare",
        "args-stripped",
    ],
)
def test_refcheck_resolve_path(dotconfigs_root, ref, base, expected):
    # Single-quote the ref so the test shell doesn't expand ${CLAUDE_PROJECT_DIR}
    # or ~ before refcheck_resolve_path sees it (real callers pass jq output,
    # which is never shell-expanded).
    script = f"""
{_source(dotconfigs_root, "refcheck.sh")}
refcheck_resolve_path '{ref}' "{base}"
"""
    result = run_bash(script)
    assert result.returncode == 0
    expected = expected.replace("{HOME}", str(Path.home()))
    assert result.stdout.strip() == expected


# ---------------------------------------------------------------------------
# refcheck_settings_json
# ---------------------------------------------------------------------------


def test_refcheck_flags_dangling_command(dotconfigs_root, tmp_path):
    settings = tmp_path / "settings.json"
    settings.write_text(
        json.dumps({"statusLine": {"command": "./missing-statusline.js"}})
    )
    script = f"""
{_source(dotconfigs_root, "refcheck.sh")}
refcheck_settings_json "{settings}" "{tmp_path}"
"""
    result = run_bash(script)
    assert result.returncode == 1
    assert "dangling reference" in result.stderr
    assert "missing-statusline.js" in result.stderr


def test_refcheck_passes_when_command_exists(dotconfigs_root, tmp_path):
    (tmp_path / "real.sh").write_text("#!/bin/sh\n")
    hook = tmp_path / "hook.sh"
    hook.write_text("#!/bin/sh\n")
    settings = tmp_path / "settings.json"
    settings.write_text(
        json.dumps(
            {
                "statusLine": {"command": "./real.sh"},
                "hooks": {
                    "PreToolUse": [
                        {"hooks": [{"type": "command", "command": "./hook.sh"}]}
                    ]
                },
            }
        )
    )
    script = f"""
{_source(dotconfigs_root, "refcheck.sh")}
refcheck_settings_json "{settings}" "{tmp_path}"
"""
    result = run_bash(script)
    assert result.returncode == 0, result.stderr
    assert "dangling" not in result.stderr


def test_refcheck_ignores_bare_path_command(dotconfigs_root, tmp_path):
    """A bare command name (resolved via PATH) is not existence-checked."""
    settings = tmp_path / "settings.json"
    settings.write_text(json.dumps({"statusLine": {"command": "starship"}}))
    script = f"""
{_source(dotconfigs_root, "refcheck.sh")}
refcheck_settings_json "{settings}" "{tmp_path}"
"""
    result = run_bash(script)
    assert result.returncode == 0, result.stderr


# ---------------------------------------------------------------------------
# _warn_merge_collisions
# ---------------------------------------------------------------------------


def _collision_script(root: Path, src: Path, tgt: Path) -> str:
    return f"""
{_source(root, "colours.sh", "deploy.sh")}
warnings=0
_warn_merge_collisions "{src}" "{tgt}"
echo "warnings=$warnings"
"""


def test_merge_collision_warns_on_differing_key(dotconfigs_root, tmp_path):
    src = tmp_path / "src.json"
    tgt = tmp_path / "tgt.json"
    src.write_text(json.dumps({"model": "opus", "outputStyle": "x"}))
    tgt.write_text(json.dumps({"model": "sonnet", "outputStyle": "x"}))
    result = run_bash(_collision_script(dotconfigs_root, src, tgt))
    assert "merge-collision: 'model'" in result.stderr
    assert "warnings=1" in result.stdout


def test_merge_collision_silent_when_identical(dotconfigs_root, tmp_path):
    src = tmp_path / "src.json"
    tgt = tmp_path / "tgt.json"
    src.write_text(json.dumps({"model": "opus"}))
    tgt.write_text(json.dumps({"model": "opus"}))
    result = run_bash(_collision_script(dotconfigs_root, src, tgt))
    assert "merge-collision" not in result.stderr
    assert "warnings=0" in result.stdout


def test_merge_collision_excludes_permissions(dotconfigs_root, tmp_path):
    """permissions are unioned, not overwritten — never a collision."""
    src = tmp_path / "src.json"
    tgt = tmp_path / "tgt.json"
    src.write_text(json.dumps({"permissions": {"allow": ["a"]}}))
    tgt.write_text(json.dumps({"permissions": {"allow": ["b"]}}))
    result = run_bash(_collision_script(dotconfigs_root, src, tgt))
    assert "merge-collision" not in result.stderr
    assert "warnings=0" in result.stdout


# ---------------------------------------------------------------------------
# deploy_from_json — source-missing is a hard error
# ---------------------------------------------------------------------------


def test_deploy_source_missing_errors_nonzero(dotconfigs_root, tmp_path):
    # A catalogue item whose source doesn't exist is a hard error (errors tally).
    script = f"""
{_source(dotconfigs_root, "symlinks.sh", "colours.sh", "deploy.sh")}
created=0; updated=0; unchanged=0; skipped=0; removed=0; errors=0; warnings=0
deploy_module "{tmp_path}/NOPE" "{tmp_path}/out" "symlink" "{tmp_path}" "false" "force"
echo "errors=$errors"
"""
    result = run_bash(script)
    assert "Error: source not found" in result.stderr
    assert "errors=1" in result.stdout


# ---------------------------------------------------------------------------
# dotconfigs validate (e2e against a copied tree)
# ---------------------------------------------------------------------------


@pytest.fixture()
def repo_copy(dotconfigs_root: Path, tmp_path: Path) -> Path:
    """A minimal runnable copy of the repo (bin + lib engine + plugins)."""
    dst = tmp_path / "repo"
    dst.mkdir()
    for item in ("bin", "lib", "plugins"):
        shutil.copytree(dotconfigs_root / item, dst / item)
    return dst


def test_validate_clean_manifests_pass(repo_copy):
    result = run_bash(f'"{repo_copy}/bin/dotconfigs" validate', cwd=repo_copy)
    assert result.returncode == 0, result.stdout + result.stderr
    assert "manifest OK" in result.stdout


def test_validate_detects_broken_manifest(repo_copy):
    manifest = repo_copy / "plugins" / "claude" / "manifest.json"
    data = json.loads(manifest.read_text())
    data["config"]["broken"] = {
        "source": "plugins/claude/DOES_NOT_EXIST",
        "target": "~/x",
        "method": "frobnicate",
        "bogus": 1,
    }
    manifest.write_text(json.dumps(data))
    result = run_bash(f'"{repo_copy}/bin/dotconfigs" validate', cwd=repo_copy)
    assert result.returncode == 1
    assert "invalid method 'frobnicate'" in result.stdout
    assert "unknown key(s): bogus" in result.stdout
    assert "source not found" in result.stdout
