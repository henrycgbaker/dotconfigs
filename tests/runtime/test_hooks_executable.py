"""Runtime tests: every deployed event hook must be executable."""

from __future__ import annotations

import os

import pytest

from tests.runtime.conftest import REPO_ROOT, catalogue_items, resolve_target

pytestmark = pytest.mark.e2e

# Event hooks only (skip the sourced `_hook-common` library).
HOOK_ITEMS = [
    i
    for i in catalogue_items(REPO_ROOT, "machine")
    if i["category"] == "hooks" and not i["name"].startswith("_")
]


@pytest.mark.parametrize("item", HOOK_ITEMS, ids=[i["label"] for i in HOOK_ITEMS])
def test_deployed_hook_executable(item, deployed_machine):
    for t in item["targets"]:
        target = resolve_target(t, deployed_machine, "machine")
        assert target.exists(), f"hook not deployed: {target}"
        assert os.access(target.resolve(), os.X_OK), f"hook not executable: {target}"
