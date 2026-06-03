"""write_with_overwrite_protection: --force overwrites (with backup); default preserves.

Backs the `global-init --force` fix - previously --force was a no-op because the
flag never reached the helper and the helper had no force path.
"""

from __future__ import annotations

from pathlib import Path

from tests.conftest import run_bash


def _call(dotconfigs_root: Path, target: Path, content: str, force: str):
    script = (
        f'source "{dotconfigs_root}/lib/init.sh"\n'
        f"write_with_overwrite_protection \"{target}\" '{content}' \"{force}\"\n"
    )
    return run_bash(script, cwd=dotconfigs_root)


class TestOverwriteProtection:
    def test_default_preserves_existing(self, tmp_path: Path, dotconfigs_root: Path):
        target = tmp_path / "global.json"
        target.write_text('{"v":1}')
        result = _call(dotconfigs_root, target, '{"v":2}', "false")
        # Non-interactive default is "skip" -> returns 1, file untouched.
        assert result.returncode == 1
        assert target.read_text() == '{"v":1}'

    def test_force_overwrites_with_backup(self, tmp_path: Path, dotconfigs_root: Path):
        target = tmp_path / "global.json"
        target.write_text('{"v":1}')
        result = _call(dotconfigs_root, target, '{"v":2}', "true")
        assert result.returncode == 0
        assert target.read_text().strip() == '{"v":2}'
        backups = list(tmp_path.glob("global.json.bak.*"))
        assert len(backups) == 1
        assert backups[0].read_text() == '{"v":1}'

    def test_creates_when_absent(self, tmp_path: Path, dotconfigs_root: Path):
        target = tmp_path / "new.json"
        result = _call(dotconfigs_root, target, '{"v":1}', "false")
        assert result.returncode == 0
        assert target.read_text().strip() == '{"v":1}'
