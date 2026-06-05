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
