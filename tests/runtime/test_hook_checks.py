"""Per-check git-hook toggles: nested deploy.json, git-config materialisation,
and the decomposed loud dispatchers.

The feature lets each *check* inside a hook be toggled individually. Toggles are
authored nested under their hook in deploy.json, materialised into git config
(`dotconfigs.<hook>.<check>`), and read by the hook dispatchers at run time
(default-on when the key is absent).
"""

from __future__ import annotations

import json

import pytest

from tests.conftest import run_bash

pytestmark = pytest.mark.e2e


def _git_env(tmp_path):
    """An isolated global/system git config so --global writes don't leak."""
    cfg = tmp_path / "gitconfig"
    cfg.write_text("")
    return {"GIT_CONFIG_GLOBAL": str(cfg), "GIT_CONFIG_SYSTEM": str(cfg)}, cfg


def test_validate_accepts_checks_field(run_dotconfigs):
    """The new `checks` manifest field must not trip cmd_validate's key whitelist."""
    r = run_dotconfigs(["validate"])
    assert r.returncode == 0, r.stderr + r.stdout
    assert "git: manifest OK" in r.stdout


def test_seed_nests_hook_checks(run_dotconfigs, tmp_path):
    sel = tmp_path / "deploy.json"
    r = run_dotconfigs(["init", "--force"], env={"DOTCONFIGS_DEPLOY_CONFIG": str(sel)})
    assert r.returncode == 0, r.stderr

    data = json.loads(sel.read_text())
    pc = data["git"]["hooks"]["pre-commit"]
    assert pc["enabled"] is True
    assert pc["checks"]["block-main"] is True
    assert pc["checks"]["secrets"] is True
    # An item without checks (config) stays a bare bool.
    assert data["git"]["config"]["gitconfig-base"] is True


def test_nested_selection_yields_full_plan(run_dotconfigs, tmp_path):
    """A nested hook value must collapse to its enabled bool, not truncate the plan.

    Regression: feeding an object into resolve_plan's @tsv used to abort the walk
    and silently drop every item after the first nested hook.
    """
    sel = tmp_path / "deploy.json"
    sel.write_text(
        json.dumps(
            {
                "git": {
                    "hooks": {
                        "pre-commit": {"enabled": True, "checks": {"block-main": False}},
                        "commit-msg": {"enabled": True, "checks": {"block-ai-attribution": True}},
                    }
                }
            }
        )
    )
    r = run_dotconfigs(["deploy", "--dry-run"], env={"DOTCONFIGS_DEPLOY_CONFIG": str(sel)})
    assert r.returncode == 0, r.stderr
    # Both nested hooks are present in the plan — nothing was truncated.
    assert "plugins/git/hooks/pre-commit" in r.stdout
    assert "plugins/git/hooks/commit-msg" in r.stdout


def test_materialise_and_unmaterialise(dotconfigs_root, tmp_path):
    env, _cfg = _git_env(tmp_path)
    sel = tmp_path / "deploy.json"
    sel.write_text(
        json.dumps(
            {
                "git": {
                    "hooks": {
                        "pre-commit": {
                            "enabled": True,
                            "checks": {"block-main": False, "secrets": True},
                        }
                    }
                }
            }
        )
    )
    script = f"""
      source "{dotconfigs_root}/lib/colours.sh"
      source "{dotconfigs_root}/lib/discovery.sh"
      source "{dotconfigs_root}/lib/symlinks.sh"
      source "{dotconfigs_root}/lib/validation.sh"
      source "{dotconfigs_root}/lib/deploy.sh"
      materialise_hook_checks "{dotconfigs_root}/plugins" "{sel}" false >/dev/null
      echo "BM=$(git config --bool dotconfigs.pre-commit.block-main)"
      echo "SE=$(git config --bool dotconfigs.pre-commit.secrets)"
      echo "ID=$(git config --bool dotconfigs.pre-commit.identity)"
      unmaterialise_hook_checks "{dotconfigs_root}/plugins" "{sel}" false >/dev/null
      echo "AFTER=[$(git config --get-regexp '^dotconfigs\\.' 2>/dev/null)]"
    """
    r = run_bash(script, env=env)
    assert "BM=false" in r.stdout, r.stdout + r.stderr  # explicit override
    assert "SE=true" in r.stdout                        # explicit true
    assert "ID=true" in r.stdout                        # default fallback (no override)
    assert "AFTER=[]" in r.stdout                       # unmaterialise cleared everything


def test_materialise_legacy_bare_bool_hook(dotconfigs_root, tmp_path):
    """A bare-bool hook value (legacy / all-defaults) must materialise every check
    at its default, not truncate. Regression: indexing .checks on a bool aborted
    the jq stream and dropped every check at and after that hook.
    """
    env, _cfg = _git_env(tmp_path)
    sel = tmp_path / "deploy.json"
    sel.write_text(json.dumps({"git": {"hooks": {"pre-commit": True}}}))
    script = f"""
      source "{dotconfigs_root}/lib/colours.sh"
      source "{dotconfigs_root}/lib/discovery.sh"
      source "{dotconfigs_root}/lib/symlinks.sh"
      source "{dotconfigs_root}/lib/validation.sh"
      source "{dotconfigs_root}/lib/deploy.sh"
      materialise_hook_checks "{dotconfigs_root}/plugins" "{sel}" false >/dev/null
      echo "PC=$(git config --global --get-regexp '^dotconfigs\\.pre-commit\\.' | wc -l | tr -d ' ')"
      echo "BM=$(git config --global --bool dotconfigs.pre-commit.block-main)"
    """
    r = run_bash(script, env=env)
    assert "PC=6" in r.stdout, r.stdout + r.stderr   # all six pre-commit checks
    assert "BM=true" in r.stdout                     # default-on


def _born_repo(repo, cfg, branch="feature", *, identity=True):
    """Bash to create a repo with a born branch and one commit."""
    ident = ""
    if identity:
        ident = (
            'git config user.name henrycgbaker\n'
            'git config user.email henry.c.g.baker@gmail.com\n'
        )
    return f"""
      export GIT_CONFIG_GLOBAL="{cfg}" GIT_CONFIG_SYSTEM="{cfg}"
      mkdir -p "{repo}" && cd "{repo}"
      git init -q -b {branch}
      {ident}
      git -c user.name=ci -c user.email=ci@x commit -q --allow-empty -m init
      echo x > f && git add f
    """


def test_block_main_default_on_then_toggle_off(dotconfigs_root, tmp_path):
    env, cfg = _git_env(tmp_path)
    repo = tmp_path / "repo"
    hook = f"{dotconfigs_root}/plugins/git/hooks/pre-commit"

    # Default (no materialised key): block-main is ON and blocks loudly.
    r1 = run_bash(_born_repo(repo, cfg, "main") + f'\n"{hook}"', env=env)
    assert r1.returncode == 1
    assert "BLOCKED by pre-commit/block-main" in r1.stderr

    # Toggled off: the block-main check is skipped, commit allowed by it.
    r2 = run_bash(
        _born_repo(repo, cfg, "main")
        + f'\ngit config --global dotconfigs.pre-commit.block-main false\n"{hook}"',
        env=env,
    )
    assert r2.returncode == 0, r2.stderr


def test_unset_identity_fails_loud_not_silent(dotconfigs_root, tmp_path):
    """Regression: an empty git identity used to abort pre-commit silently (set -e
    killed the hook at the `git config user.name` substitution before its error
    could print). It must now block loudly with a named reason.
    """
    env, cfg = _git_env(tmp_path)
    repo = tmp_path / "repo"
    hook = f"{dotconfigs_root}/plugins/git/hooks/pre-commit"
    # Born branch but NO persistent user.name/user.email anywhere.
    r = run_bash(_born_repo(repo, cfg, "feature", identity=False) + f'\n"{hook}"', env=env)
    assert r.returncode == 1
    assert "BLOCKED by pre-commit/identity" in r.stderr
