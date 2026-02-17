"""Unit tests for lib/deploy.sh — the JSON-driven deployment engine."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from tests.conftest import run_bash, run_bash_function

pytestmark = pytest.mark.unit


# ---------------------------------------------------------------------------
# parse_modules — include/exclude logic
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "include,exclude,expected_csv",
    [
        (["a", "b", "c"], [], "a,b,c"),
        (["a", "b", "c"], ["b"], "a,c"),
        (["a", "b", "c"], ["a", "c"], "b"),
        (["a", "b", "c"], ["a", "b", "c"], "__NONE__"),
        (["a", "b", "c"], ["d"], "a,b,c"),  # exclude non-existent
        (["a"], ["a"], "__NONE__"),
        ([], [], "__NONE__"),
        (["a", "b"], None, "a,b"),  # no exclude key at all
    ],
    ids=[
        "no-exclude",
        "exclude-one",
        "exclude-two",
        "exclude-all",
        "exclude-nonexistent",
        "single-exclude-match",
        "empty-both",
        "no-exclude-key",
    ],
)
def test_parse_modules_include_exclude(
    dotconfigs_root: Path,
    tmp_path: Path,
    include: list[str],
    exclude: list[str] | None,
    expected_csv: str,
):
    """parse_modules computes include - exclude correctly (jq expression)."""
    module: dict = {
        "source": "plugins/claude/hooks",
        "target": ".claude/hooks",
        "method": "symlink",
        "include": include,
    }
    if exclude is not None:
        module["exclude"] = exclude

    config = {"claude": {"hooks": module}}
    config_file = tmp_path / "config.json"
    config_file.write_text(json.dumps(config))

    result = run_bash_function(
        dotconfigs_root, "lib/deploy.sh", "parse_modules", [str(config_file)]
    )

    assert result.returncode == 0

    lines = [line for line in result.stdout.strip().splitlines() if line.strip()]
    assert len(lines) == 1, f"Expected 1 TSV line, got {len(lines)}: {lines}"
    cols = lines[0].split("\t")
    assert len(cols) == 4
    assert cols[0] == "plugins/claude/hooks"
    assert cols[1] == ".claude/hooks"
    assert cols[2] == "symlink"
    assert cols[3] == expected_csv


# ---------------------------------------------------------------------------
# parse_modules_in_group — group filtering
# ---------------------------------------------------------------------------


class TestParseModulesInGroup:
    """Tests for parse_modules_in_group group filtering."""

    @pytest.fixture()
    def multi_group_config(self, tmp_path: Path) -> Path:
        config = {
            "claude": {
                "hooks": {
                    "source": "plugins/claude/hooks",
                    "target": ".claude/hooks",
                    "method": "symlink",
                    "include": ["block-destructive.sh"],
                }
            },
            "git": {
                "hooks": {
                    "source": "plugins/git/hooks",
                    "target": ".git/hooks",
                    "method": "symlink",
                    "include": ["pre-commit"],
                }
            },
        }
        p = tmp_path / "multi.json"
        p.write_text(json.dumps(config))
        return p

    def test_filter_by_group(self, dotconfigs_root: Path, multi_group_config: Path):
        result = run_bash_function(
            dotconfigs_root,
            "lib/deploy.sh",
            "parse_modules_in_group",
            [str(multi_group_config), "claude"],
        )
        assert result.returncode == 0
        lines = [line for line in result.stdout.strip().splitlines() if line.strip()]
        assert len(lines) == 1
        assert "plugins/claude/hooks" in lines[0]

    def test_empty_group_returns_all(
        self, dotconfigs_root: Path, multi_group_config: Path
    ):
        """Empty group key falls through to parse_modules (returns all)."""
        result = run_bash_function(
            dotconfigs_root,
            "lib/deploy.sh",
            "parse_modules_in_group",
            [str(multi_group_config), ""],
        )
        assert result.returncode == 0
        lines = [line for line in result.stdout.strip().splitlines() if line.strip()]
        assert len(lines) == 2

    def test_missing_group_returns_empty(
        self, dotconfigs_root: Path, multi_group_config: Path
    ):
        result = run_bash_function(
            dotconfigs_root,
            "lib/deploy.sh",
            "parse_modules_in_group",
            [str(multi_group_config), "nonexistent"],
        )
        assert result.returncode == 0
        lines = [line for line in result.stdout.strip().splitlines() if line.strip()]
        assert len(lines) == 0


# ---------------------------------------------------------------------------
# deploy_directory_files — symlink creation with include CSV
# ---------------------------------------------------------------------------


class TestDeployDirectoryFiles:
    """Tests for deploy_directory_files."""

    def test_include_csv_creates_only_listed_files(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
echo "CREATED=$created SKIPPED=$skipped"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert (target / "block-destructive.sh").is_symlink()
        assert not (target / "post-tool-format.py").exists()

    def test_dry_run_creates_nothing(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "true" "force"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert "Would link" in result.stdout
        assert not target.exists()

    def test_missing_include_file_warns(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "nonexistent.sh" "{root}" "false" "force"
echo "SKIPPED=$skipped"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert "Warning" in result.stdout
        assert "SKIPPED=1" in result.stdout

    def test_empty_include_deploys_all(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "" "{root}" "false" "force"
echo "CREATED=$created"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert (target / "block-destructive.sh").is_symlink()


# ---------------------------------------------------------------------------
# deploy_from_json — full pipeline
# ---------------------------------------------------------------------------


class TestDeployFromJson:
    """Tests for deploy_from_json end-to-end."""

    def test_dry_run_full_pipeline(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        config = {
            "claude": {
                "hooks": {
                    "source": "plugins/claude/hooks",
                    "target": str(tmp_path / "hooks"),
                    "method": "symlink",
                    "include": ["block-destructive.sh", "post-tool-format.py"],
                }
            }
        }
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config))

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
deploy_from_json "{config_file}" "{root}" "" "true" "false"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert "Dry-run mode" in result.stdout
        assert "Would link" in result.stdout
        assert not (tmp_path / "hooks").exists()

    def test_group_filter(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        config = {
            "claude": {
                "hooks": {
                    "source": "plugins/claude/hooks",
                    "target": str(tmp_path / "claude_hooks"),
                    "method": "symlink",
                    "include": ["block-destructive.sh"],
                }
            },
            "git": {
                "hooks": {
                    "source": "plugins/git/hooks",
                    "target": str(tmp_path / "git_hooks"),
                    "method": "symlink",
                    "include": ["pre-commit"],
                }
            },
        }
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config))

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
deploy_from_json "{config_file}" "{root}" "claude" "false" "true"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert (tmp_path / "claude_hooks" / "block-destructive.sh").is_symlink()
        assert not (tmp_path / "git_hooks").exists()

    def test_missing_config_errors(self, dotconfigs_root: Path):
        script = f"""
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
deploy_from_json "/nonexistent/config.json" "{dotconfigs_root}" "" "false" "false"
"""
        result = run_bash(script)
        assert result.returncode != 0
        assert "Error" in result.stdout

    def test_summary_counts(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        root = fake_source_tree()
        config = {
            "claude": {
                "hooks": {
                    "source": "plugins/claude/hooks",
                    "target": str(tmp_path / "hooks"),
                    "method": "symlink",
                    "include": [
                        "block-destructive.sh",
                        "nonexistent.sh",
                    ],
                }
            }
        }
        config_file = tmp_path / "config.json"
        config_file.write_text(json.dumps(config))

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
deploy_from_json "{config_file}" "{root}" "" "false" "true"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert "Updated:   1" in result.stdout
        assert "Skipped:   1" in result.stdout


# ---------------------------------------------------------------------------
# deploy preserves foreign files — regression test for directory-wipe bug
# ---------------------------------------------------------------------------


class TestDeployPreservesForeignFiles:
    """Deploy must not remove files it doesn't own in shared directories."""

    def test_foreign_files_survive_deploy(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """Pre-existing non-dotconfigs files in target dir must survive deploy."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "hooks"

        # Pre-populate target with "foreign" files (e.g. GSD hooks)
        target.mkdir(parents=True)
        foreign_file = target / "gsd-check-update.js"
        foreign_file.write_text("// GSD hook\n")
        foreign_symlink = target / "foreign-link.sh"
        foreign_symlink.symlink_to(foreign_file)

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
"""
        result = run_bash(script)
        assert result.returncode == 0
        # Dotconfigs file deployed
        assert (target / "block-destructive.sh").is_symlink()
        # Foreign files untouched
        assert foreign_file.exists(), "Foreign file was deleted by deploy"
        assert foreign_file.read_text() == "// GSD hook\n"
        assert foreign_symlink.is_symlink(), "Foreign symlink was deleted by deploy"

    def test_target_dir_symlink_preserved(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """A target path that is a symlink to a valid directory must not be replaced."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"

        # Create a real directory and symlink to it (simulates dotclaude setup)
        real_dir = tmp_path / "real_hooks"
        real_dir.mkdir()
        (real_dir / "existing.sh").write_text("# existing\n")
        target = tmp_path / "hooks_link"
        target.symlink_to(real_dir)

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
"""
        result = run_bash(script)
        assert result.returncode == 0
        # Symlink to directory preserved (not replaced with real dir)
        assert target.is_symlink(), "Directory symlink was replaced"
        assert target.resolve() == real_dir.resolve()
        # Dotconfigs file deployed inside
        assert (target / "block-destructive.sh").is_symlink()
        # Pre-existing file untouched
        assert (real_dir / "existing.sh").exists()


# ---------------------------------------------------------------------------
# cleanup_stale_in_directory — convergent cleanup
# ---------------------------------------------------------------------------


class TestCleanupStaleSymlinks:
    """Tests for convergent cleanup during deploy."""

    def test_stale_dotconfigs_symlink_removed(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """Stale dotconfigs-owned symlinks are removed after deploy."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        # Pre-populate target with a stale dotconfigs-owned symlink
        target.mkdir(parents=True)
        stale = target / "old-hook.sh"
        stale.symlink_to(source / "block-destructive.sh")  # points into dotconfigs tree

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0; removed=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
echo "REMOVED=$removed"
"""
        result = run_bash(script)
        assert result.returncode == 0
        # Deployed file present
        assert (target / "block-destructive.sh").is_symlink()
        # Stale symlink removed
        assert not stale.exists(), "Stale dotconfigs symlink was not removed"
        assert "REMOVED=1" in result.stdout

    def test_broken_symlink_removed(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """Broken/dangling symlinks are removed after deploy."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        # Pre-populate target with a broken symlink
        target.mkdir(parents=True)
        broken = target / "deleted-hook.py"
        broken.symlink_to("/nonexistent/path/to/nowhere")

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0; removed=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
echo "REMOVED=$removed"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert (
            not broken.exists() and not broken.is_symlink()
        ), "Broken symlink was not removed"
        assert "REMOVED=1" in result.stdout

    def test_foreign_files_preserved_during_cleanup(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """Foreign regular files and foreign valid symlinks survive cleanup."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        # Pre-populate with foreign file + foreign symlink
        target.mkdir(parents=True)
        foreign_file = target / "gsd-check-update.js"
        foreign_file.write_text("// GSD hook\n")
        foreign_symlink = target / "foreign-link.sh"
        foreign_symlink.symlink_to(foreign_file)

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0; removed=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "false" "force"
echo "REMOVED=$removed"
"""
        result = run_bash(script)
        assert result.returncode == 0
        # Foreign files preserved
        assert foreign_file.exists(), "Foreign file was removed during cleanup"
        assert (
            foreign_symlink.is_symlink()
        ), "Foreign symlink was removed during cleanup"
        assert "REMOVED=0" in result.stdout

    def test_cleanup_dry_run(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """Dry-run reports stale entries but does not remove them."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        # Pre-populate with stale dotconfigs symlink + broken symlink
        target.mkdir(parents=True)
        stale = target / "old-hook.sh"
        stale.symlink_to(source / "block-destructive.sh")
        broken = target / "deleted.py"
        broken.symlink_to("/nonexistent/path")

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0; removed=0
deploy_directory_files "{source}" "{target}" "block-destructive.sh" "{root}" "true" "force"
echo "REMOVED=$removed"
"""
        result = run_bash(script)
        assert result.returncode == 0
        # Both still exist (dry-run)
        assert stale.is_symlink(), "Stale symlink was removed during dry-run"
        assert broken.is_symlink(), "Broken symlink was removed during dry-run"
        # But reported
        assert "Would remove" in result.stdout
        assert "REMOVED=2" in result.stdout

    def test_none_exclude_cleans_all_stale(
        self, dotconfigs_root: Path, fake_source_tree, tmp_path: Path
    ):
        """__NONE__ include (all excluded) still cleans stale dotconfigs symlinks."""
        root = fake_source_tree()
        source = root / "plugins" / "claude" / "hooks"
        target = tmp_path / "target_hooks"

        # Pre-populate with a dotconfigs-owned symlink
        target.mkdir(parents=True)
        stale = target / "old-hook.sh"
        stale.symlink_to(source / "block-destructive.sh")
        # And a foreign file that should survive
        foreign = target / "keep-me.txt"
        foreign.write_text("user file\n")

        script = f"""
set -e
source "{dotconfigs_root}/lib/symlinks.sh"
source "{dotconfigs_root}/lib/validation.sh"
source "{dotconfigs_root}/lib/deploy.sh"
created=0; updated=0; unchanged=0; skipped=0; removed=0
deploy_directory_files "{source}" "{target}" "__NONE__" "{root}" "false" "force"
echo "REMOVED=$removed"
"""
        result = run_bash(script)
        assert result.returncode == 0
        assert not stale.exists(), "Stale symlink not cleaned with __NONE__"
        assert foreign.exists(), "Foreign file was removed with __NONE__"
        assert "REMOVED=1" in result.stdout
