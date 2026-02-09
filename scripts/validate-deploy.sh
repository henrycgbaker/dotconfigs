#!/bin/bash
# validate-deploy.sh — E2E validation that deployed config matches reality
# Checks that what dotconfigs configured is what git & Claude Code actually see.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"

pass=0
fail=0
skip=0

green="\033[32m"
red="\033[31m"
yellow="\033[33m"
reset="\033[0m"

check_pass() {
    echo -e "  ${green}✓${reset} $1"
    pass=$((pass + 1))
}

check_fail() {
    echo -e "  ${red}✗${reset} $1"
    fail=$((fail + 1))
}

check_skip() {
    echo -e "  ${yellow}–${reset} $1 (skipped)"
    skip=$((skip + 1))
}

# Load .env if it exists
load_env() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: .env not found at $ENV_FILE"
        echo "Run 'dotconfigs global-configs' first."
        exit 1
    fi
    set -a
    source "$ENV_FILE"
    set +a
}

echo "═══════════════════════════════════════════════════════════"
echo "  dotconfigs E2E Validation"
echo "═══════════════════════════════════════════════════════════"
echo ""

load_env

# ─── Claude Plugin ───────────────────────────────────────────

echo "Claude Plugin:"

deploy_target="${CLAUDE_DEPLOY_TARGET:-$HOME/.claude}"

# 1. settings.json symlink
if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
    source_file="$REPO_ROOT/plugins/claude/settings.json"
    target_link="$deploy_target/settings.json"

    if [[ -L "$target_link" ]]; then
        actual_target=$(readlink "$target_link")
        if [[ "$actual_target" == "$source_file" ]]; then
            # Verify the target file is valid JSON
            if python3 -c "import json; json.load(open('$target_link'))" 2>/dev/null; then
                check_pass "settings.json symlink correct + valid JSON"
            else
                check_fail "settings.json symlink correct but invalid JSON"
            fi
        else
            check_fail "settings.json symlink → $actual_target (expected $source_file)"
        fi
    elif [[ -f "$target_link" ]]; then
        check_fail "settings.json exists but is not a symlink (foreign file)"
    else
        check_fail "settings.json not found at $target_link"
    fi

    # Verify schema: no invalid keys
    if [[ -f "$target_link" ]]; then
        invalid_keys=$(python3 -c "
import json, sys
d = json.load(open('$target_link'))
valid = {'permissions', 'sandbox', 'hooks', 'env', 'model', 'apiKey', 'customApiHeaders'}
invalid = set(d.keys()) - valid
if invalid:
    print(', '.join(invalid))
" 2>/dev/null || echo "parse_error")
        if [[ -z "$invalid_keys" ]]; then
            check_pass "settings.json schema valid (no unknown top-level keys)"
        elif [[ "$invalid_keys" == "parse_error" ]]; then
            check_fail "settings.json could not be parsed"
        else
            check_fail "settings.json has unknown keys: $invalid_keys"
        fi

        # Check sandbox.excludedCommands (not excluded_commands)
        has_bad_sandbox=$(python3 -c "
import json
d = json.load(open('$target_link'))
s = d.get('sandbox', {})
if 'excluded_commands' in s:
    print('bad')
elif 'excludedCommands' in s:
    print('ok')
else:
    print('none')
" 2>/dev/null || echo "error")
        case "$has_bad_sandbox" in
            ok)   check_pass "sandbox uses correct camelCase (excludedCommands)" ;;
            bad)  check_fail "sandbox uses snake_case (excluded_commands) — should be excludedCommands" ;;
            none) check_skip "sandbox section has no excludedCommands" ;;
            *)    check_fail "could not parse sandbox section" ;;
        esac
    fi
else
    check_skip "settings.json (CLAUDE_SETTINGS_ENABLED=false)"
fi

# 2. CLAUDE.md symlink (CLAUDE_MD_SECTIONS is space-separated list)
if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
    source_file="$REPO_ROOT/plugins/claude/CLAUDE.md"
    target_link="$deploy_target/CLAUDE.md"

    if [[ -L "$target_link" ]]; then
        actual_target=$(readlink "$target_link")
        if [[ "$actual_target" == "$source_file" ]]; then
            if [[ -s "$target_link" ]]; then
                check_pass "CLAUDE.md symlink correct + non-empty"
            else
                check_fail "CLAUDE.md symlink correct but file is empty"
            fi
        else
            check_fail "CLAUDE.md symlink → $actual_target (expected $source_file)"
        fi
    elif [[ -f "$target_link" ]]; then
        check_fail "CLAUDE.md exists but is not a symlink (foreign file)"
    else
        check_fail "CLAUDE.md not found at $target_link"
    fi
else
    check_skip "CLAUDE.md (no CLAUDE_MD_SECTIONS configured)"
fi

# 3. Hooks (CLAUDE_HOOKS_ENABLED is a space-separated list of hook filenames)
if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
    IFS=' ' read -ra hook_list <<< "$CLAUDE_HOOKS_ENABLED"
    for hook_name in "${hook_list[@]}"; do
        hook_file="$REPO_ROOT/plugins/claude/hooks/$hook_name"
        target_link="$deploy_target/hooks/$hook_name"

        if [[ ! -f "$hook_file" ]]; then
            check_fail "hook $hook_name configured but source not found"
            continue
        fi

        if [[ -L "$target_link" ]]; then
            actual_target=$(readlink "$target_link")
            if [[ "$actual_target" == "$hook_file" ]]; then
                if [[ -x "$hook_file" ]]; then
                    check_pass "hook $hook_name symlink correct + executable"
                else
                    check_fail "hook $hook_name symlink correct but source not executable"
                fi
            else
                check_fail "hook $hook_name symlink → $actual_target (expected $hook_file)"
            fi
        else
            check_fail "hook $hook_name not symlinked at $target_link"
        fi
    done
else
    check_skip "claude hooks (none configured)"
fi

# 4. Skills/Commands (CLAUDE_SKILLS_ENABLED is a space-separated list of skill names without .md)
if [[ -n "${CLAUDE_SKILLS_ENABLED:-}" ]]; then
    IFS=' ' read -ra skill_list <<< "$CLAUDE_SKILLS_ENABLED"
    for skill_name in "${skill_list[@]}"; do
        skill_file="$REPO_ROOT/plugins/claude/commands/${skill_name}.md"
        target_link="$deploy_target/commands/${skill_name}.md"

        if [[ ! -f "$skill_file" ]]; then
            check_fail "skill ${skill_name}.md configured but source not found"
            continue
        fi

        if [[ -L "$target_link" ]]; then
            actual_target=$(readlink "$target_link")
            if [[ "$actual_target" == "$skill_file" ]]; then
                check_pass "skill ${skill_name}.md symlink correct"
            else
                check_fail "skill ${skill_name}.md symlink → $actual_target (expected $skill_file)"
            fi
        else
            check_fail "skill ${skill_name}.md not symlinked at $target_link"
        fi
    done
else
    check_skip "claude skills (none configured)"
fi

echo ""

# ─── Git Plugin ──────────────────────────────────────────────

echo "Git Plugin:"

# 5. Identity
if [[ -n "${GIT_USER_NAME:-}" ]]; then
    actual_name=$(git config --global user.name 2>/dev/null || echo "")
    if [[ "$actual_name" == "$GIT_USER_NAME" ]]; then
        check_pass "git user.name = '$actual_name'"
    else
        check_fail "git user.name = '$actual_name' (expected '$GIT_USER_NAME')"
    fi
else
    check_skip "git user.name (not configured)"
fi

if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
    actual_email=$(git config --global user.email 2>/dev/null || echo "")
    if [[ "$actual_email" == "$GIT_USER_EMAIL" ]]; then
        check_pass "git user.email = '$actual_email'"
    else
        check_fail "git user.email = '$actual_email' (expected '$GIT_USER_EMAIL')"
    fi
else
    check_skip "git user.email (not configured)"
fi

# 6. Workflow settings
if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
    actual_rebase=$(git config --global pull.rebase 2>/dev/null || echo "")
    if [[ "$actual_rebase" == "$GIT_PULL_REBASE" ]]; then
        check_pass "git pull.rebase = '$actual_rebase'"
    else
        check_fail "git pull.rebase = '$actual_rebase' (expected '$GIT_PULL_REBASE')"
    fi
else
    check_skip "git pull.rebase (not configured)"
fi

# 7. Aliases (GIT_ALIASES_ENABLED is a space-separated list of alias names)
if [[ -n "${GIT_ALIASES_ENABLED:-}" ]]; then
    IFS=' ' read -ra alias_list <<< "$GIT_ALIASES_ENABLED"
    alias_count=${#alias_list[@]}
    alias_match=0
    for alias_name in "${alias_list[@]}"; do
        actual=$(git config --global "alias.$alias_name" 2>/dev/null || echo "")
        if [[ -n "$actual" ]]; then
            alias_match=$((alias_match + 1))
        fi
    done

    if [[ $alias_match -eq $alias_count ]]; then
        check_pass "git aliases: $alias_match/$alias_count deployed"
    else
        check_fail "git aliases: $alias_match/$alias_count deployed"
    fi
else
    check_skip "git aliases (none configured)"
fi

# 8. Git hooks exist and are executable
hook_dir="$REPO_ROOT/plugins/git/hooks"
if [[ -d "$hook_dir" ]]; then
    hook_count=0
    exec_count=0
    for hook in "$hook_dir"/*; do
        [[ ! -f "$hook" ]] && continue
        hook_count=$((hook_count + 1))
        [[ -x "$hook" ]] && exec_count=$((exec_count + 1))
    done

    if [[ $exec_count -eq $hook_count ]]; then
        check_pass "git hooks: $hook_count hooks, all executable"
    else
        check_fail "git hooks: $exec_count/$hook_count executable"
    fi
else
    check_skip "git hooks directory not found"
fi

echo ""

# ─── CLI & PATH ──────────────────────────────────────────────

echo "CLI & PATH:"

# 9. dotconfigs symlink on PATH
dotconfigs_path="$HOME/.local/bin/dotconfigs"
if [[ -L "$dotconfigs_path" ]]; then
    actual_target=$(readlink "$dotconfigs_path")
    if [[ "$actual_target" == "$REPO_ROOT/dotconfigs" ]]; then
        check_pass "dotconfigs PATH symlink correct"
    else
        check_fail "dotconfigs PATH symlink → $actual_target (expected $REPO_ROOT/dotconfigs)"
    fi
else
    check_fail "dotconfigs PATH symlink not found at $dotconfigs_path"
fi

# 10. dots symlink on PATH
dots_path="$HOME/.local/bin/dots"
if [[ -L "$dots_path" ]]; then
    actual_target=$(readlink "$dots_path")
    if [[ "$actual_target" == "$REPO_ROOT/dotconfigs" ]]; then
        check_pass "dots PATH symlink correct"
    else
        check_fail "dots PATH symlink → $actual_target (expected $REPO_ROOT/dotconfigs)"
    fi
else
    check_fail "dots PATH symlink not found at $dots_path"
fi

# 11. dots repo symlink
dots_repo="$REPO_ROOT/dots"
if [[ -L "$dots_repo" ]]; then
    actual_target=$(readlink "$dots_repo")
    if [[ "$actual_target" == "dotconfigs" ]]; then
        check_pass "dots → dotconfigs symlink in repo"
    else
        check_fail "dots → $actual_target (expected 'dotconfigs')"
    fi
else
    check_fail "dots symlink not found in repo root"
fi

echo ""

# ─── Summary ─────────────────────────────────────────────────

total=$((pass + fail + skip))
echo "═══════════════════════════════════════════════════════════"
if [[ $fail -eq 0 ]]; then
    echo -e "  ${green}ALL CHECKS PASSED${reset}  ($pass passed, $skip skipped)"
else
    echo -e "  ${red}FAILURES DETECTED${reset}  ($pass passed, $fail failed, $skip skipped)"
fi
echo "═══════════════════════════════════════════════════════════"

exit $fail
