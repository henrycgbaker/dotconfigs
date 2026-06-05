"""Runtime tests: `dotconfigs setup` puts both `dotconfigs` and `dots` on PATH."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.e2e


def test_setup_creates_path_symlinks(tmp_path, run_dotconfigs, dotconfigs_root):
    home = tmp_path / "home"
    (home / ".local" / "bin").mkdir(parents=True)

    result = run_dotconfigs(["setup"], env={"HOME": str(home)})
    assert result.returncode == 0, result.stderr

    entry = (dotconfigs_root / "src" / "dotconfigs").resolve()
    for name in ("dotconfigs", "dots"):
        link = home / ".local" / "bin" / name
        assert link.is_symlink(), f"{name} not symlinked onto PATH"
        assert link.resolve() == entry
