"""E2E tests for CLI routing, help, and error handling."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.e2e


# ---------------------------------------------------------------------------
# Routing basics
# ---------------------------------------------------------------------------


def test_no_args_shows_usage(run_dotconfigs):
    result = run_dotconfigs([])
    assert result.returncode == 0
    assert "Usage:" in result.stdout


def test_help_flag(run_dotconfigs):
    result = run_dotconfigs(["--help"])
    assert result.returncode == 0
    assert "Usage:" in result.stdout


def test_unknown_command_errors(run_dotconfigs):
    result = run_dotconfigs(["nonexistent-cmd"])
    assert result.returncode != 0
    assert "Unknown command" in result.stderr


# ---------------------------------------------------------------------------
# help <command>
# ---------------------------------------------------------------------------


@pytest.mark.parametrize(
    "cmd,expected_fragment",
    [
        ("deploy", "Deploy global configuration"),
        ("project", "Deploy per-project"),
        ("project-init", "Scaffold per-project"),
        ("status", "deployment status"),
        ("setup", "One-time initialisation"),
        ("global-init", "Scaffold global.json"),
    ],
)
def test_help_subcommand(run_dotconfigs, cmd, expected_fragment):
    result = run_dotconfigs(["help", cmd])
    assert result.returncode == 0
    assert expected_fragment in result.stdout


def test_help_unknown_command(run_dotconfigs):
    result = run_dotconfigs(["help", "bogus"])
    assert result.returncode != 0
    assert "Unknown command" in result.stderr


# ---------------------------------------------------------------------------
# Error handling
# ---------------------------------------------------------------------------


def test_deploy_unknown_option(run_dotconfigs):
    result = run_dotconfigs(["deploy", "--bogus"])
    assert result.returncode != 0
    assert "Unknown option" in result.stderr


def test_project_unknown_option(run_dotconfigs, project_dir):
    result = run_dotconfigs(["project", str(project_dir), "--bogus"])
    assert result.returncode != 0
    assert "Unknown option" in result.stderr


def test_project_on_non_git_dir(run_dotconfigs, tmp_path):
    plain_dir = tmp_path / "no_git"
    plain_dir.mkdir()
    result = run_dotconfigs(["project", str(plain_dir)])
    assert result.returncode != 0
    assert "git" in result.stderr.lower()
