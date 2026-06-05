"""E2E tests for CLI routing, help, and error handling."""

from __future__ import annotations

import pytest

pytestmark = pytest.mark.e2e


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


@pytest.mark.parametrize(
    "cmd,expected_fragment",
    [
        ("setup", "One-time initialisation"),
        ("init", "Seed a selection"),
        ("deploy", "Deploy a selection"),
        ("undeploy", "Remove deployed artefacts"),
        ("cleanup", "stale and broken symlinks"),
        ("status", "deployment status"),
        ("validate", "Lint catalogues"),
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


def test_deploy_unknown_option(run_dotconfigs):
    result = run_dotconfigs(["deploy", "--bogus"])
    assert result.returncode != 0
    assert "Unknown option" in result.stderr


def test_deploy_project_on_non_git_dir(run_dotconfigs, tmp_path):
    plain = tmp_path / "no_git"
    plain.mkdir()
    result = run_dotconfigs(["deploy", str(plain)])
    assert result.returncode != 0
    assert "git" in result.stderr.lower()


def test_init_project_on_non_git_dir(run_dotconfigs, tmp_path):
    plain = tmp_path / "no_git2"
    plain.mkdir()
    result = run_dotconfigs(["init", str(plain)])
    assert result.returncode != 0
    assert "git" in result.stderr.lower()
