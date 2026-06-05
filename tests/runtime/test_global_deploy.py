"""Runtime tests: machine deploy produces correct filesystem state.

Parametrized over every machine-scope catalogue item (manifest.json is the SSOT),
so adding a plugin or item automatically extends coverage.
"""

from __future__ import annotations

import json

import pytest

from tests.runtime.conftest import REPO_ROOT, catalogue_items, validate_item

pytestmark = pytest.mark.e2e

MACHINE_ITEMS = catalogue_items(REPO_ROOT, "machine")


@pytest.mark.parametrize("item", MACHINE_ITEMS, ids=[i["label"] for i in MACHINE_ITEMS])
def test_machine_item_deployed(item, deployed_machine, dotconfigs_root):
    failures = validate_item(item, dotconfigs_root, deployed_machine, "machine")
    assert not failures, "\n".join(failures)


def test_settings_hooks_synthesised(deployed_machine):
    settings = json.loads((deployed_machine / ".claude" / "settings.json").read_text())
    assert "hooks" in settings, "synthesised hooks block missing"
    commands = [
        h["command"]
        for arr in settings["hooks"].values()
        for block in arr
        for h in block["hooks"]
    ]
    # A selected, wired guard is present...
    assert any("block-rm-rf-root.sh" in c for c in commands)
    # ...and non-hook keys from the merge source survive.
    assert "permissions" in settings and "sandbox" in settings


def _env(home):
    return {
        "HOME": str(home),
        "DOTCONFIGS_DEPLOY_CONFIG": str(home / ".dotconfigs" / "deploy.json"),
    }


def test_settings_idempotent_from_first_deploy(tmp_path, run_dotconfigs):
    """settings.json (merge) must be byte-stable across re-deploys, including the
    very first one — regression for the cp-then-merge non-idempotency."""
    home = tmp_path / "home"
    home.mkdir()
    env = _env(home)
    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0
    settings = home / ".claude" / "settings.json"
    first = settings.read_text()
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0
    assert settings.read_text() == first, (
        "settings.json must be stable across re-deploys"
    )


def test_deselecting_all_hooks_clears_settings_block(tmp_path, run_dotconfigs):
    """Toggling every Claude hook off must clear the synthesised hooks block (the
    merge owns .hooks wholesale) while preserving non-hook keys — regression for
    stale wiring surviving a deselect."""
    home = tmp_path / "home"
    home.mkdir()
    dj = home / ".dotconfigs" / "deploy.json"
    env = _env(home)
    assert run_dotconfigs(["init", "--force"], env=env).returncode == 0
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0
    settings = home / ".claude" / "settings.json"
    assert json.loads(settings.read_text())["hooks"], "expected a populated block first"

    sel = json.loads(dj.read_text())
    sel["claude"]["hooks"] = {k: False for k in sel["claude"]["hooks"]}
    dj.write_text(json.dumps(sel))
    assert run_dotconfigs(["deploy", "--force"], env=env).returncode == 0

    data = json.loads(settings.read_text())
    wired = [
        h for arr in data.get("hooks", {}).values() for blk in arr for h in blk["hooks"]
    ]
    assert wired == [], "deselecting all hooks must clear the settings hooks block"
    assert "permissions" in data  # non-hook keys preserved
