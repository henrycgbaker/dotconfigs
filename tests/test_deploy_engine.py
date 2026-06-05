"""Unit tests for the catalogue → selection → plan engine in src/lib.

Covers _merged_manifest, seed_deploy_json (init.sh), resolve_plan, and
synthesise_claude_hooks — the join between the catalogue (manifest.json) and the
instance selection (deploy.json).
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit

TAB = "\t"


def _engine(root: Path, body: str):
    script = f"""
source "{root}/src/lib/deploy.sh"
source "{root}/src/lib/init.sh"
PLUGINS_DIR="{root}/plugins"
{body}
"""
    return run_bash(script)


def test_merged_manifest_nests_plugin_category_name(dotconfigs_root):
    res = _engine(dotconfigs_root, '_merged_manifest "$PLUGINS_DIR"')
    data = json.loads(res.stdout)
    assert data["claude"]["hooks"]["block-rm-rf-root"]["method"] == "symlink"
    assert "commit" in data["claude"]["skills"]
    assert "gitconfig-base" in data["git"]["config"]


def test_seed_machine_excludes_project_only_items(dotconfigs_root):
    data = json.loads(_engine(dotconfigs_root, "seed_deploy_json machine").stdout)
    assert "block-rm-rf-root" in data["claude"]["hooks"]
    assert "gitconfig-base" in data["git"]["config"]
    # project-only items must not appear in the machine seed
    assert "project-excludes" not in data.get("git", {}).get("excludes", {})


def test_seed_project_is_relative_only(dotconfigs_root):
    data = json.loads(_engine(dotconfigs_root, "seed_deploy_json project").stdout)
    assert "project-excludes" in data["git"]["excludes"]
    # machine-only config absent; dual-scope skills present
    assert "gitconfig-base" not in data.get("git", {}).get("config", {})
    assert "commit" in data["claude"]["skills"]


def test_multi_target_item_spans_scopes(dotconfigs_root):
    data = json.loads(
        _engine(dotconfigs_root, '_merged_manifest "$PLUGINS_DIR"').stdout
    )
    targets = data["claude"]["skills"]["commit"]["target"]
    assert any(t.startswith("~") for t in targets)
    assert any(not t.startswith(("~", "/")) for t in targets)


def test_resolve_plan_machine_rows_are_scoped_and_enabled(dotconfigs_root, tmp_path):
    sel = tmp_path / "deploy.json"
    res = _engine(
        dotconfigs_root,
        f'seed_deploy_json machine > "{sel}"; resolve_plan "$PLUGINS_DIR" "{sel}" machine',
    )
    rows = [r.split(TAB) for r in res.stdout.strip().splitlines()]
    labels = [r[4] for r in rows]
    assert "claude/hooks/block-rm-rf-root" in labels
    for enabled, _source, target, _method, _label in rows:
        assert enabled == "true"  # seeded defaults are all on
        assert target.startswith(("~", "/"))  # machine scope only


def test_resolve_plan_reflects_toggle(dotconfigs_root, tmp_path):
    sel = tmp_path / "deploy.json"
    _engine(dotconfigs_root, f'seed_deploy_json machine > "{sel}"')
    data = json.loads(sel.read_text())
    data["claude"]["hooks"]["block-drop-table"] = False
    sel.write_text(json.dumps(data))

    res = _engine(dotconfigs_root, f'resolve_plan "$PLUGINS_DIR" "{sel}" machine')
    enabled = {
        r.split(TAB)[4]: r.split(TAB)[0] for r in res.stdout.strip().splitlines()
    }
    assert enabled["claude/hooks/block-drop-table"] == "false"
    assert enabled["claude/hooks/block-rm-rf-root"] == "true"


def _synth_commands(root, sel):
    hooks = json.loads(
        _engine(root, f'synthesise_claude_hooks "$PLUGINS_DIR" "{sel}"').stdout
    )
    return [h["command"] for arr in hooks.values() for blk in arr for h in blk["hooks"]]


def test_synthesise_hooks_drops_deselected(dotconfigs_root, tmp_path):
    sel = tmp_path / "deploy.json"
    _engine(dotconfigs_root, f'seed_deploy_json machine > "{sel}"')
    assert any(
        "block-drop-table.sh" in c for c in _synth_commands(dotconfigs_root, sel)
    )

    data = json.loads(sel.read_text())
    data["claude"]["hooks"]["block-drop-table"] = False
    sel.write_text(json.dumps(data))
    cmds = _synth_commands(dotconfigs_root, sel)
    assert not any("block-drop-table.sh" in c for c in cmds)
    assert any("block-rm-rf-root.sh" in c for c in cmds)  # others survive


def test_synthesise_hooks_groups_multi_wiring(dotconfigs_root, tmp_path):
    """A hook with two wiring entries (gh + MCP) lands in both matcher groups."""
    sel = tmp_path / "deploy.json"
    _engine(dotconfigs_root, f'seed_deploy_json machine > "{sel}"')
    hooks = json.loads(
        _engine(
            dotconfigs_root, f'synthesise_claude_hooks "$PLUGINS_DIR" "{sel}"'
        ).stdout
    )
    matchers = {blk.get("matcher") for blk in hooks["PreToolUse"]}
    assert "Bash" in matchers
    assert "mcp__github__.*" in matchers
