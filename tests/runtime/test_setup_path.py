"""Runtime tests: `dotconfigs setup` puts both `dotconfigs` and `dots` on PATH."""

from __future__ import annotations

import pytest


@pytest.mark.runtime
class TestSetupPathSymlinks:
    """Confirm setup creates ~/.local/bin/{dotconfigs,dots} pointing at the entry point."""

    def test_creates_both_symlinks_in_local_bin(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        home = tmp_path_factory.mktemp("home")
        (home / ".local" / "bin").mkdir(parents=True)

        result = run_dotconfigs(["setup"], env={"HOME": str(home)})
        assert result.returncode == 0, (
            f"setup failed (rc={result.returncode}):\n"
            f"stdout: {result.stdout}\nstderr: {result.stderr}"
        )

        entry = dotconfigs_root / "dotconfigs"
        local_bin = home / ".local" / "bin"
        for name in ("dotconfigs", "dots"):
            link = local_bin / name
            assert link.is_symlink(), f"{name} symlink missing at {link}"
            assert link.resolve() == entry.resolve(), (
                f"{name} symlink points to {link.resolve()}, expected {entry}"
            )

    def test_idempotent(
        self, tmp_path_factory, dotconfigs_root, run_dotconfigs
    ):
        """Running setup twice leaves the same symlinks in place."""
        home = tmp_path_factory.mktemp("home")
        (home / ".local" / "bin").mkdir(parents=True)

        for _ in range(2):
            result = run_dotconfigs(["setup"], env={"HOME": str(home)})
            assert result.returncode == 0

        entry = dotconfigs_root / "dotconfigs"
        for name in ("dotconfigs", "dots"):
            link = home / ".local" / "bin" / name
            assert link.is_symlink()
            assert link.resolve() == entry.resolve()
