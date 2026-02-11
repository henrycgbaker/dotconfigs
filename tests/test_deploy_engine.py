"""Unit tests for lib/deploy.sh — the JSON-driven deployment engine."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from conftest import run_bash, run_bash_function

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
        assert (target / "post-tool-format.py").is_symlink()


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
                        "post-tool-format.py",
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
        assert "Updated:   2" in result.stdout
        assert "Skipped:   1" in result.stdout
