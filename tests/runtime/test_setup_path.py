"""Runtime tests: `dotconfigs setup` puts both `dotconfigs` and `dots` on PATH."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.e2e


def test_setup_creates_path_symlinks(tmp_path, run_dotconfigs, dotconfigs_root):
    home = tmp_path / "home"
    (home / ".local" / "bin").mkdir(parents=True)

    result = run_dotconfigs(["setup"], env={"HOME": str(home)})
    assert result.returncode == 0, result.stderr

    entry = (dotconfigs_root / "bin" / "dotconfigs").resolve()
    for name in ("dotconfigs", "dots"):
        link = home / ".local" / "bin" / name
        assert link.is_symlink(), f"{name} not symlinked onto PATH"
        assert link.resolve() == entry


def test_setup_repoints_stale_links_noninteractively(
    tmp_path, run_dotconfigs, dotconfigs_root
):
    """A stale/broken dotconfigs-owned link is self-healed without a prompt.

    Regression: setup used to leave a relocated entry point's dangling links in
    place (the non-interactive overwrite prompt defaults to "no"), so a re-run
    after moving the entry point never fixed PATH.
    """
    bindir = tmp_path / "home" / ".local" / "bin"
    bindir.mkdir(parents=True)
    entry = (dotconfigs_root / "bin" / "dotconfigs").resolve()

    for name in ("dotconfigs", "dots"):
        link = bindir / name
        link.symlink_to(tmp_path / "old" / "dotconfigs")  # broken: target absent
        assert link.is_symlink() and not link.exists()

    result = run_dotconfigs(["setup"], env={"DOTCONFIGS_BIN_DIR": str(bindir)})
    assert result.returncode == 0, result.stderr

    for name in ("dotconfigs", "dots"):
        link = bindir / name
        assert link.resolve() == entry, f"{name} not repointed to the new entry"


def test_setup_respects_bin_dir_override(tmp_path, run_dotconfigs, dotconfigs_root):
    """DOTCONFIGS_BIN_DIR forces the CLI symlink location (and creates it)."""
    home = tmp_path / "home"
    home.mkdir()
    bindir = tmp_path / "opt" / "bin"  # does not exist yet

    result = run_dotconfigs(
        ["setup"], env={"HOME": str(home), "DOTCONFIGS_BIN_DIR": str(bindir)}
    )
    assert result.returncode == 0, result.stderr

    entry = (dotconfigs_root / "bin" / "dotconfigs").resolve()
    for name in ("dotconfigs", "dots"):
        link = bindir / name
        assert link.is_symlink(), f"{name} not placed in DOTCONFIGS_BIN_DIR"
        assert link.resolve() == entry
    # and nothing leaked into the default ~/.local/bin
    assert not (home / ".local" / "bin" / "dotconfigs").exists()


def test_init_seeds_env_file_from_example(tmp_path, run_dotconfigs):
    """A first machine init copies .env.example to the instance .env (DOTCONFIGS_ENV)."""
    home = tmp_path / "home"
    env_file = tmp_path / "env"
    result = run_dotconfigs(
        ["init", "--force"],
        env={
            "HOME": str(home),
            "DOTCONFIGS_DEPLOY_CONFIG": str(tmp_path / "deploy.json"),
            "DOTCONFIGS_ENV": str(env_file),
        },
    )
    assert result.returncode == 0, result.stderr
    assert env_file.exists(), "init did not seed the instance .env"
    body = env_file.read_text()
    assert "DOTCONFIGS_AUTHOR_NAME" in body and "DOTCONFIGS_BIN_DIR" in body
