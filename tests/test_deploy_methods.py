"""End-to-end unit tests for every deploy method in lib/deploy.sh.

One file that drives `deploy_module` (and `undeploy_module`) directly for each
of the four methods, asserting the happy path, idempotency, and the property
that makes each method distinct:

- symlink : target is a live symlink into the source
- append  : seed-once; source lines present, idempotent re-deploy
- managed : sentinel block, updatable in place + reversible, user lines kept
- merge   : deep-merge JSON, base wins, permission arrays unioned, never symlink
"""

from __future__ import annotations

import json
import os
from pathlib import Path

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.unit

BEGIN = "# >>> dotconfigs:"
END = "# <<< dotconfigs:"

_LIBS = """
source "{root}/lib/symlinks.sh"
source "{root}/lib/validation.sh"
source "{root}/lib/deploy.sh"
"""


def _deploy(
    root: Path,
    source: Path,
    target: Path,
    method: str,
    dry: str = "false",
    dc_root: Path | None = None,
):
    # `|| _drc=$?` keeps a non-zero no-op return (e.g. merge's idempotent path)
    # from aborting under set -e before the counters are echoed. dc_root is the
    # ownership root passed to deploy_module (defaults to root); symlink tests
    # pass source.parent so the deployed link resolves as dotconfigs-owned, the
    # way a real source under the repo root does.
    dc = dc_root if dc_root is not None else root
    script = f"""
set -e
{_LIBS.format(root=root)}
created=0; updated=0; unchanged=0; skipped=0; removed=0; errors=0; warnings=0
_drc=0
deploy_module "{source}" "{target}" "{method}" "{dc}" "{dry}" "force" || _drc=$?
echo "C=$created U=$updated N=$unchanged S=$skipped E=$errors"
"""
    return run_bash(script)


def _undeploy(root: Path, source: Path, target: Path, method: str, dry: str = "false"):
    script = f"""
set -e
{_LIBS.format(root=root)}
removed=0; skipped=0; unchanged=0
_drc=0
undeploy_module "{source}" "{target}" "{method}" "{root}" "{dry}" || _drc=$?
echo "R=$removed S=$skipped N=$unchanged"
"""
    return run_bash(script)


# ---------------------------------------------------------------------------
# symlink
# ---------------------------------------------------------------------------


def test_symlink_links_to_source(dotconfigs_root, tmp_path):
    source = tmp_path / "src.sh"
    source.write_text("echo hi\n")
    target = tmp_path / "out" / "dst.sh"

    res = _deploy(dotconfigs_root, source, target, "symlink")
    assert res.returncode == 0, res.stderr
    assert target.is_symlink()
    assert os.path.realpath(target) == os.path.realpath(source)


def test_symlink_idempotent(dotconfigs_root, tmp_path):
    source = tmp_path / "src.sh"
    source.write_text("echo hi\n")
    target = tmp_path / "dst.sh"

    first = _deploy(dotconfigs_root, source, target, "symlink", dc_root=source.parent)
    second = _deploy(dotconfigs_root, source, target, "symlink", dc_root=source.parent)
    assert "C=1" in first.stdout
    assert "N=1" in second.stdout  # unchanged on re-deploy


def test_symlink_preserves_foreign_symlink_at_target(dotconfigs_root, tmp_path):
    """A foreign symlink at the target (pointing outside the root) is NOT treated
    as dotconfigs-owned, so it is preserved rather than silently overwritten in
    non-interactive mode. Guards the backup_and_link ownership-root fix."""
    root = tmp_path / "repo"
    root.mkdir()
    src = root / "src.sh"
    src.write_text("echo hi\n")
    foreign = tmp_path / "elsewhere.sh"
    foreign.write_text("# foreign\n")
    dest = tmp_path / "dest.sh"
    dest.symlink_to(foreign)

    res = run_bash(
        f'source "{dotconfigs_root}/lib/symlinks.sh"\n'
        f'backup_and_link "{src}" "{dest}" "dest.sh" "false" "{root}"\n'
    )
    assert dest.is_symlink()
    assert os.path.realpath(dest) == os.path.realpath(foreign), (
        "foreign symlink preserved"
    )
    assert "Skipped" in res.stdout


# ---------------------------------------------------------------------------
# append (seed-once)
# ---------------------------------------------------------------------------


def test_append_adds_lines_regular_file(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("pattern-a\npattern-b\n")
    target = tmp_path / "out" / ".gitignore"

    res = _deploy(dotconfigs_root, source, target, "append")
    assert res.returncode == 0, res.stderr
    assert not target.is_symlink()
    text = target.read_text()
    assert "pattern-a" in text and "pattern-b" in text


def test_append_idempotent_no_duplication(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("pattern-a\npattern-b\n")
    target = tmp_path / ".gitignore"

    first = _deploy(dotconfigs_root, source, target, "append")
    after_first = target.read_text()
    second = _deploy(dotconfigs_root, source, target, "append")

    assert "U=1" in first.stdout  # appended
    assert "N=1" in second.stdout  # already present -> unchanged
    assert target.read_text() == after_first
    assert target.read_text().count("pattern-a") == 1  # not duplicated


def test_append_preserves_existing_user_content(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("managed-pattern\n")
    target = tmp_path / ".gitignore"
    target.write_text("# user's own\nmy-secret\n")

    _deploy(dotconfigs_root, source, target, "append")
    text = target.read_text()
    assert "my-secret" in text  # user content intact
    assert "managed-pattern" in text


# ---------------------------------------------------------------------------
# managed (sentinel block: updatable + reversible)
# ---------------------------------------------------------------------------


def test_managed_writes_block(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("alpha\nbeta\n")
    target = tmp_path / "out" / "exclude"  # nested dir must be created

    res = _deploy(dotconfigs_root, source, target, "managed")
    assert res.returncode == 0, res.stderr
    assert "C=1" in res.stdout
    text = target.read_text()
    assert text.count(BEGIN) == 1 and text.count(END) == 1
    assert text.index(BEGIN) < text.index("alpha") < text.index(END)


def test_managed_idempotent(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("alpha\nbeta\n")
    target = tmp_path / "exclude"

    first = _deploy(dotconfigs_root, source, target, "managed")
    after_first = target.read_text()
    second = _deploy(dotconfigs_root, source, target, "managed")

    assert "C=1" in first.stdout
    assert "N=1" in second.stdout
    assert target.read_text() == after_first
    assert target.read_text().count(BEGIN) == 1


def test_managed_updates_block_in_place(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("alpha\nbeta\n")
    target = tmp_path / "exclude"
    _deploy(dotconfigs_root, source, target, "managed")

    source.write_text("alpha\ngamma\n")  # beta removed, gamma added
    res = _deploy(dotconfigs_root, source, target, "managed")

    assert "U=1" in res.stdout  # updated in place, not re-appended
    text = target.read_text()
    assert text.count(BEGIN) == 1  # single block
    assert "gamma" in text and "beta" not in text  # stale line gone


def test_managed_preserves_user_lines_across_update(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("managed-line\n")
    target = tmp_path / "exclude"
    target.write_text("secret.key\n")

    _deploy(dotconfigs_root, source, target, "managed")
    source.write_text("managed-line-v2\n")
    _deploy(dotconfigs_root, source, target, "managed")

    text = target.read_text()
    assert "secret.key" in text  # user line survives an update
    assert "managed-line-v2" in text
    assert "managed-line\n" not in text.replace("managed-line-v2", "")


def test_managed_undeploy_removes_block_keeps_user_lines(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("managed-line\n")
    target = tmp_path / "exclude"
    target.write_text("secret.key\n")
    _deploy(dotconfigs_root, source, target, "managed")
    assert BEGIN in target.read_text()

    res = _undeploy(dotconfigs_root, source, target, "managed")
    assert "R=1" in res.stdout
    text = target.read_text()
    assert BEGIN not in text and END not in text  # block fully removed
    assert "managed-line" not in text
    assert "secret.key" in text  # user line preserved
    assert target.exists()  # file not deleted


def test_managed_undeploy_noop_when_absent(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("managed-line\n")
    target = tmp_path / "exclude"
    target.write_text("just-user-lines\n")  # no managed block

    res = _undeploy(dotconfigs_root, source, target, "managed")
    assert "N=1" in res.stdout
    assert target.read_text() == "just-user-lines\n"


def test_managed_broken_end_marker_preserves_user_lines(dotconfigs_root, tmp_path):
    """A hand-broken block (begin present, end marker gone) must not swallow the
    user's lines below it — malformed input is preserved, never deleted."""
    source = tmp_path / "src"
    source.write_text("fresh\n")
    target = tmp_path / "exclude"
    begin = f"# >>> dotconfigs:{source} >>>"  # marker key == abs source path here
    # begin present, NO end marker, real user lines below it
    target.write_text(f"{begin}\nstale-managed\nUSER-LINE-1\nUSER-LINE-2\n")

    _deploy(dotconfigs_root, source, target, "managed")
    text = target.read_text()
    assert "USER-LINE-1" in text and "USER-LINE-2" in text  # not swallowed
    assert "fresh" in text  # fresh block still written
    # Converges: the orphan begin marker is stripped, leaving exactly one block.
    assert text.count(BEGIN) == 1


def test_managed_undeploy_broken_marker_keeps_user_lines(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("fresh\n")
    target = tmp_path / "exclude"
    begin = f"# >>> dotconfigs:{source} >>>"
    target.write_text(f"{begin}\nstale\nUSER-LINE\n")  # unterminated block

    _undeploy(dotconfigs_root, source, target, "managed")
    text = target.read_text()
    assert "USER-LINE" in text  # user content survives undeploy
    assert BEGIN not in text  # stray begin marker cleaned up too


def test_managed_reconverges_after_double_begin(dotconfigs_root, tmp_path):
    """Two begin markers with one end (a corrupted state) must not swallow the
    user line between them, and must collapse back to a single clean block."""
    source = tmp_path / "src"
    source.write_text("fresh\n")
    target = tmp_path / "exclude"
    begin = f"# >>> dotconfigs:{source} >>>"
    end = f"# <<< dotconfigs:{source} <<<"
    target.write_text(f"{begin}\nA\nKEEP-ME\n{begin}\nB\n{end}\n")

    _deploy(dotconfigs_root, source, target, "managed")
    text = target.read_text()
    assert "KEEP-ME" in text  # user line between the two begins survives
    assert text.count(BEGIN) == 1 and text.count(END) == 1  # single block again


def test_managed_dry_run_writes_nothing(dotconfigs_root, tmp_path):
    source = tmp_path / "src"
    source.write_text("alpha\n")
    target = tmp_path / "exclude"

    res = _deploy(dotconfigs_root, source, target, "managed", dry="true")
    assert "Would write managed block" in res.stdout
    assert not target.exists()


def test_managed_source_without_trailing_newline(dotconfigs_root, tmp_path):
    """End marker must land on its own line even if source lacks a final \\n."""
    source = tmp_path / "src"
    source.write_text("no-newline-here")  # no trailing newline
    target = tmp_path / "exclude"

    _deploy(dotconfigs_root, source, target, "managed")
    lines = target.read_text().splitlines()
    assert any(ln.startswith(END) for ln in lines)
    assert "no-newline-here" in lines  # its own line, not glued to END


# ---------------------------------------------------------------------------
# merge (deep-merge JSON, preserve local)
# ---------------------------------------------------------------------------


def test_merge_creates_regular_json_file(dotconfigs_root, tmp_path):
    source = tmp_path / "base.json"
    source.write_text(json.dumps({"permissions": {"allow": ["Bash(ls)"]}}))
    target = tmp_path / "out" / "settings.json"

    res = _deploy(dotconfigs_root, source, target, "merge")
    assert res.returncode == 0, res.stderr
    assert not target.is_symlink()
    data = json.loads(target.read_text())
    assert "Bash(ls)" in data["permissions"]["allow"]


def test_merge_unions_permissions_and_is_idempotent(dotconfigs_root, tmp_path):
    source = tmp_path / "base.json"
    source.write_text(json.dumps({"permissions": {"allow": ["Bash(ls)"]}}))
    target = tmp_path / "settings.json"
    # Pre-existing local grant the app wrote — must survive the merge.
    target.write_text(json.dumps({"permissions": {"allow": ["Bash(git status)"]}}))

    first = _deploy(dotconfigs_root, source, target, "merge")
    allow = set(json.loads(target.read_text())["permissions"]["allow"])
    assert {"Bash(ls)", "Bash(git status)"} <= allow  # unioned, local preserved

    second = _deploy(dotconfigs_root, source, target, "merge")
    assert "N=1" in second.stdout  # idempotent re-merge
    assert "U=1" in first.stdout
