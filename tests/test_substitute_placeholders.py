"""Tests for _substitute_placeholders in lib/deploy.sh.

Covers the attribution-templating step: {{AUTHOR_NAME}}/{{AUTHOR_EMAIL}} are
replaced from `git config --global`, with a hardcoded fallback (and stderr
warning) when the git identity is unset. Source files without placeholders are
passed through untouched; an unparseable source falls back to the original.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit


def _runner(dotconfigs_root: Path, src: Path) -> str:
    """A bash snippet that runs _substitute_placeholders and prints a parseable
    RC / OUT / content envelope."""
    return f"""
source "{dotconfigs_root}/lib/colours.sh"
source "{dotconfigs_root}/lib/deploy.sh"
out=$(_substitute_placeholders "{src}")
echo "RC=$?"
echo "OUT=$out"
echo "---CONTENT---"
cat "$out"
"""


def _git_env(global_config: Path) -> dict[str, str]:
    """Isolate git from the real user/system config."""
    return {"GIT_CONFIG_GLOBAL": str(global_config), "GIT_CONFIG_NOSYSTEM": "1"}


def _parse(stdout: str) -> tuple[int, str, str]:
    rc_line, out_line, _, *content = stdout.splitlines()
    rc = int(rc_line.removeprefix("RC="))
    out = out_line.removeprefix("OUT=")
    return rc, out, "\n".join(content)


def test_no_placeholders_returns_source_unchanged(dotconfigs_root, tmp_path):
    src = tmp_path / "settings.json"
    src.write_text(json.dumps({"model": "opus"}))
    cfg = tmp_path / "gitconfig"
    cfg.write_text("[user]\n  name = Jane Dev\n  email = jane@example.com\n")

    result = run_bash(_runner(dotconfigs_root, src), env=_git_env(cfg))
    rc, out, content = _parse(result.stdout)

    assert rc == 0
    assert out == str(src)  # untouched: same path back, no temp file
    assert json.loads(content) == {"model": "opus"}


def test_substitutes_from_git_config(dotconfigs_root, tmp_path):
    src = tmp_path / "settings.json"
    src.write_text(
        json.dumps(
            {"attribution": {"name": "{{AUTHOR_NAME}}", "email": "{{AUTHOR_EMAIL}}"}}
        )
    )
    cfg = tmp_path / "gitconfig"
    cfg.write_text("[user]\n  name = Jane Dev\n  email = jane@example.com\n")

    result = run_bash(_runner(dotconfigs_root, src), env=_git_env(cfg))
    rc, out, content = _parse(result.stdout)

    assert rc == 0
    assert out != str(src)  # substitution writes a temp file
    data = json.loads(content)
    assert data["attribution"] == {"name": "Jane Dev", "email": "jane@example.com"}
    assert "attribution:" not in result.stderr  # no fallback warning


def test_substitutes_from_included_gitconfig(dotconfigs_root, tmp_path):
    """Identity defined only in an [include]d file (like our gitconfig-base) is
    resolved via --includes, not mistaken for unset and forced to the fallback."""
    src = tmp_path / "settings.json"
    src.write_text(
        json.dumps(
            {"attribution": {"name": "{{AUTHOR_NAME}}", "email": "{{AUTHOR_EMAIL}}"}}
        )
    )
    base = tmp_path / "gitconfig-base"
    base.write_text("[user]\n  name = henrycgbaker\n  email = hcb@example.com\n")
    cfg = tmp_path / "gitconfig"
    cfg.write_text(f"[include]\n  path = {base}\n")

    result = run_bash(_runner(dotconfigs_root, src), env=_git_env(cfg))
    rc, _out, content = _parse(result.stdout)

    assert rc == 0
    data = json.loads(content)
    assert data["attribution"] == {"name": "henrycgbaker", "email": "hcb@example.com"}
    assert "attribution:" not in result.stderr  # resolved via include, no fallback


def test_env_identity_used_before_hardcoded_fallback(dotconfigs_root, tmp_path):
    """With no git identity, DOTCONFIGS_AUTHOR_* (from the instance .env) is used
    before the hardcoded default — and without the fallback warning."""
    src = tmp_path / "settings.json"
    src.write_text(
        json.dumps(
            {"attribution": {"name": "{{AUTHOR_NAME}}", "email": "{{AUTHOR_EMAIL}}"}}
        )
    )
    empty = tmp_path / "empty_gitconfig"
    empty.write_text("")
    env = {
        **_git_env(empty),
        "DOTCONFIGS_AUTHOR_NAME": "Env Person",
        "DOTCONFIGS_AUTHOR_EMAIL": "env@example.com",
    }

    result = run_bash(_runner(dotconfigs_root, src), env=env)
    rc, _out, content = _parse(result.stdout)

    assert rc == 0
    data = json.loads(content)
    assert data["attribution"] == {"name": "Env Person", "email": "env@example.com"}
    assert "attribution:" not in result.stderr  # not the hardcoded fallback


def test_git_config_wins_over_env(dotconfigs_root, tmp_path):
    """git config is authoritative: it takes precedence over the .env defaults."""
    src = tmp_path / "settings.json"
    src.write_text(
        json.dumps(
            {"attribution": {"name": "{{AUTHOR_NAME}}", "email": "{{AUTHOR_EMAIL}}"}}
        )
    )
    cfg = tmp_path / "gitconfig"
    cfg.write_text("[user]\n  name = Git Person\n  email = git@example.com\n")
    env = {
        **_git_env(cfg),
        "DOTCONFIGS_AUTHOR_NAME": "Env Person",
        "DOTCONFIGS_AUTHOR_EMAIL": "env@example.com",
    }

    result = run_bash(_runner(dotconfigs_root, src), env=env)
    _rc, _out, content = _parse(result.stdout)
    assert json.loads(content)["attribution"]["name"] == "Git Person"


def test_falls_back_when_git_config_empty(dotconfigs_root, tmp_path):
    src = tmp_path / "settings.json"
    src.write_text(
        json.dumps(
            {"attribution": {"name": "{{AUTHOR_NAME}}", "email": "{{AUTHOR_EMAIL}}"}}
        )
    )
    empty = tmp_path / "empty_gitconfig"
    empty.write_text("")

    result = run_bash(_runner(dotconfigs_root, src), env=_git_env(empty))
    rc, _out, content = _parse(result.stdout)

    assert rc == 0
    data = json.loads(content)
    assert data["attribution"] == {
        "name": "Henry Baker",
        "email": "henry.c.g.baker@gmail.com",
    }
    assert "attribution:" in result.stderr  # fallback warns on stderr


def test_invalid_json_source_falls_back_to_original(dotconfigs_root, tmp_path):
    src = tmp_path / "broken.json"
    src.write_text('{ "attribution": "{{AUTHOR_NAME}}" not json ')
    cfg = tmp_path / "gitconfig"
    cfg.write_text("[user]\n  name = Jane Dev\n  email = jane@example.com\n")

    result = run_bash(_runner(dotconfigs_root, src), env=_git_env(cfg))
    rc, out, _content = _parse(result.stdout)

    assert rc == 1  # jq failed
    assert out == str(src)  # but deploy still gets a usable path back
