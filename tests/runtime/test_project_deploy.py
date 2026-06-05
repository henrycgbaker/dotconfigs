"""Runtime tests: project deploy produces correct filesystem state.

Parametrized over every project-scope catalogue item (manifest.json is the SSOT).
"""

from __future__ import annotations

import pytest

from tests.runtime.conftest import REPO_ROOT, catalogue_items, validate_item

pytestmark = pytest.mark.e2e

PROJECT_ITEMS = catalogue_items(REPO_ROOT, "project")


@pytest.mark.parametrize("item", PROJECT_ITEMS, ids=[i["label"] for i in PROJECT_ITEMS])
def test_project_item_deployed(item, deployed_project, dotconfigs_root):
    failures = validate_item(item, dotconfigs_root, deployed_project, "project")
    assert not failures, "\n".join(failures)


def test_dotconfigs_excluded(deployed_project):
    exclude = (deployed_project / ".git" / "info" / "exclude").read_text()
    assert ".dotconfigs/" in exclude
