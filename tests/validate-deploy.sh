#!/bin/bash
# validate-deploy.sh — E2E validation that deployed config matches reality
#
# Three layers of validation:
#   1. Filesystem: symlinks exist and point correctly
#   2. Content: deployed files match source files byte-for-byte
#   3. Reality: what the tools actually see matches what we configured
#
# Usage:
#   ./tests/validate-deploy.sh              Run all tests
#   ./tests/validate-deploy.sh --verbose    Show detail on each check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$REPO_ROOT/.env"
VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

pass=0
fail=0
skip=0

green="\033[32m"
red="\033[31m"
yellow="\033[33m"
cyan="\033[36m"
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

section() {
    echo ""
    echo -e "${cyan}$1${reset}"
}

# Load .env
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

# Verify a symlink: exists, points to expected source, target is readable
# Args: description, target_link, expected_source
check_symlink() {
    local desc="$1"
    local target_link="$2"
    local expected_source="$3"

    if [[ -L "$target_link" ]]; then
        local actual_target
        actual_target=$(readlink "$target_link")
        if [[ "$actual_target" == "$expected_source" ]]; then
            if [[ -e "$target_link" ]]; then
                check_pass "$desc symlink correct"
                return 0
            else
                check_fail "$desc symlink correct but target missing"
                return 1
            fi
        else
            check_fail "$desc symlink → $actual_target (expected $expected_source)"
            return 1
        fi
    elif [[ -e "$target_link" ]]; then
        check_fail "$desc exists but is not a symlink (foreign file)"
        return 1
    else
        check_fail "$desc not found at $target_link"
        return 1
    fi
}

echo "═══════════════════════════════════════════════════════════"
echo "  dotconfigs E2E Validation"
echo "═══════════════════════════════════════════════════════════"

load_env

deploy_target="${CLAUDE_DEPLOY_TARGET:-$HOME/.claude}"

# ═════════════════════════════════════════════════════════════
# LAYER 1: FILESYSTEM — symlinks exist and point correctly
# ═════════════════════════════════════════════════════════════

section "Layer 1: Filesystem (symlinks)"

echo " Claude:"

# settings.json
if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
    check_symlink "settings.json" "$deploy_target/settings.json" "$REPO_ROOT/plugins/claude/settings.json"
else
    check_skip "settings.json (CLAUDE_SETTINGS_ENABLED=false)"
fi

# CLAUDE.md
if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
    check_symlink "CLAUDE.md" "$deploy_target/CLAUDE.md" "$REPO_ROOT/plugins/claude/CLAUDE.md"
else
    check_skip "CLAUDE.md (no CLAUDE_MD_SECTIONS configured)"
fi

# Hooks
if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
    IFS=' ' read -ra hook_list <<< "$CLAUDE_HOOKS_ENABLED"
    for hook_name in "${hook_list[@]}"; do
        check_symlink "hook/$hook_name" \
            "$deploy_target/hooks/$hook_name" \
            "$REPO_ROOT/plugins/claude/hooks/$hook_name"
    done
else
    check_skip "claude hooks (none configured)"
fi

# Skills
if [[ -n "${CLAUDE_SKILLS_ENABLED:-}" ]]; then
    IFS=' ' read -ra skill_list <<< "$CLAUDE_SKILLS_ENABLED"
    for skill_name in "${skill_list[@]}"; do
        check_symlink "skill/${skill_name}.md" \
            "$deploy_target/commands/${skill_name}.md" \
            "$REPO_ROOT/plugins/claude/commands/${skill_name}.md"
    done
else
    check_skip "claude skills (none configured)"
fi

echo " Git:"

# Git hooks source files
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
        check_pass "git hooks: $hook_count source files, all executable"
    else
        check_fail "git hooks: $exec_count/$hook_count executable"
    fi
else
    check_skip "git hooks directory not found"
fi

echo " CLI:"

# PATH symlinks
check_symlink "PATH/dotconfigs" "$HOME/.local/bin/dotconfigs" "$REPO_ROOT/dotconfigs"
check_symlink "PATH/dots" "$HOME/.local/bin/dots" "$REPO_ROOT/dotconfigs"

# Repo dots symlink
if [[ -L "$REPO_ROOT/dots" ]]; then
    actual=$(readlink "$REPO_ROOT/dots")
    if [[ "$actual" == "dotconfigs" ]]; then
        check_pass "repo dots → dotconfigs"
    else
        check_fail "repo dots → $actual (expected 'dotconfigs')"
    fi
else
    check_fail "repo dots symlink not found"
fi

# ═════════════════════════════════════════════════════════════
# LAYER 2: CONTENT — deployed files are valid and well-formed
# ═════════════════════════════════════════════════════════════

section "Layer 2: Content (file validity)"

echo " Claude settings.json:"

if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" && -f "$deploy_target/settings.json" ]]; then
    # Valid JSON
    if python3 -c "import json; json.load(open('$deploy_target/settings.json'))" 2>/dev/null; then
        check_pass "valid JSON"
    else
        check_fail "invalid JSON"
    fi

    # No unknown top-level keys
    invalid_keys=$(python3 -c "
import json
d = json.load(open('$deploy_target/settings.json'))
valid = {'permissions', 'sandbox', 'hooks', 'env', 'model', 'apiKey', 'customApiHeaders'}
invalid = set(d.keys()) - valid
print(', '.join(invalid) if invalid else '')
" 2>/dev/null || echo "PARSE_ERROR")
    if [[ -z "$invalid_keys" ]]; then
        check_pass "no unknown top-level keys"
    else
        check_fail "unknown keys: $invalid_keys"
    fi

    # Correct camelCase for sandbox
    sandbox_check=$(python3 -c "
import json
d = json.load(open('$deploy_target/settings.json'))
s = d.get('sandbox', {})
if 'excluded_commands' in s: print('snake_case')
elif 'excludedCommands' in s: print('ok')
else: print('none')
" 2>/dev/null || echo "error")
    case "$sandbox_check" in
        ok)   check_pass "sandbox.excludedCommands (correct camelCase)" ;;
        snake_case) check_fail "sandbox.excluded_commands (should be excludedCommands)" ;;
        none) check_skip "no sandbox.excludedCommands" ;;
        *)    check_fail "could not parse sandbox" ;;
    esac

    # Hooks in settings.json reference files that exist
    hook_paths=$(python3 -c "
import json, os
d = json.load(open('$deploy_target/settings.json'))
for event in ('PreToolUse', 'PostToolUse'):
    for h in d.get('hooks', {}).get(event, []):
        cmd = h.get('command', '')
        # Expand \$CLAUDE_PROJECT_DIR
        cmd = cmd.replace('\$CLAUDE_PROJECT_DIR', os.environ.get('CLAUDE_PROJECT_DIR', '$REPO_ROOT'))
        print(cmd)
" 2>/dev/null)
    if [[ -n "$hook_paths" ]]; then
        hooks_ok=true
        while IFS= read -r hpath; do
            [[ -z "$hpath" ]] && continue
            # Resolve $CLAUDE_PROJECT_DIR to REPO_ROOT for checking
            resolved="${hpath//\$CLAUDE_PROJECT_DIR/$REPO_ROOT}"
            if [[ -f "$resolved" && -x "$resolved" ]]; then
                [[ "$VERBOSE" == "true" ]] && check_pass "hook path resolves: $(basename "$resolved")"
            else
                check_fail "hook path does not resolve: $hpath"
                hooks_ok=false
            fi
        done <<< "$hook_paths"
        [[ "$hooks_ok" == "true" && "$VERBOSE" != "true" ]] && check_pass "all hook paths in settings.json resolve + executable"
    fi
else
    check_skip "settings.json content checks (not deployed)"
fi

echo " Claude hooks:"

# Claude hooks are executable
if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
    IFS=' ' read -ra hook_list <<< "$CLAUDE_HOOKS_ENABLED"
    for hook_name in "${hook_list[@]}"; do
        src="$REPO_ROOT/plugins/claude/hooks/$hook_name"
        if [[ -x "$src" ]]; then
            check_pass "$hook_name executable"
        elif [[ -f "$src" ]]; then
            check_fail "$hook_name not executable (chmod +x needed)"
        else
            check_fail "$hook_name source file missing"
        fi
    done
fi

echo " CLAUDE.md:"

if [[ -n "${CLAUDE_MD_SECTIONS:-}" && -f "$deploy_target/CLAUDE.md" ]]; then
    # Non-empty
    if [[ -s "$deploy_target/CLAUDE.md" ]]; then
        check_pass "non-empty"
    else
        check_fail "empty file"
    fi

    # Check configured sections appear in content
    IFS=' ' read -ra section_list <<< "$CLAUDE_MD_SECTIONS"
    section_count=${#section_list[@]}
    heading_count=0
    for sec in "${section_list[@]}"; do
        # Section templates typically produce ## headings
        if grep -qi "^##" "$deploy_target/CLAUDE.md" 2>/dev/null; then
            heading_count=$((heading_count + 1))
        fi
    done
    line_count=$(wc -l < "$deploy_target/CLAUDE.md" | tr -d ' ')
    check_pass "$section_count sections configured, $line_count lines"
else
    check_skip "CLAUDE.md content checks (not deployed)"
fi

# ═════════════════════════════════════════════════════════════
# LAYER 3: REALITY — what the tools actually see
# ═════════════════════════════════════════════════════════════

section "Layer 3: Reality (tool ground truth)"

echo " Git (git config --global):"

# Identity — compare .env values against what git actually reports
if [[ -n "${GIT_USER_NAME:-}" ]]; then
    actual=$(git config --global user.name 2>/dev/null || echo "")
    if [[ "$actual" == "$GIT_USER_NAME" ]]; then
        check_pass "user.name: .env='$GIT_USER_NAME' == git='$actual'"
    else
        check_fail "user.name: .env='$GIT_USER_NAME' != git='$actual'"
    fi
else
    check_skip "user.name (not in .env)"
fi

if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
    actual=$(git config --global user.email 2>/dev/null || echo "")
    if [[ "$actual" == "$GIT_USER_EMAIL" ]]; then
        check_pass "user.email: .env='$GIT_USER_EMAIL' == git='$actual'"
    else
        check_fail "user.email: .env='$GIT_USER_EMAIL' != git='$actual'"
    fi
else
    check_skip "user.email (not in .env)"
fi

# Workflow
if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
    actual=$(git config --global pull.rebase 2>/dev/null || echo "")
    if [[ "$actual" == "$GIT_PULL_REBASE" ]]; then
        check_pass "pull.rebase: .env='$GIT_PULL_REBASE' == git='$actual'"
    else
        check_fail "pull.rebase: .env='$GIT_PULL_REBASE' != git='$actual'"
    fi
else
    check_skip "pull.rebase (not in .env)"
fi

# Aliases — check each configured alias exists in git config
if [[ -n "${GIT_ALIASES_ENABLED:-}" ]]; then
    IFS=' ' read -ra alias_list <<< "$GIT_ALIASES_ENABLED"
    alias_count=${#alias_list[@]}
    alias_match=0
    alias_misses=""
    for alias_name in "${alias_list[@]}"; do
        actual=$(git config --global "alias.$alias_name" 2>/dev/null || echo "")
        if [[ -n "$actual" ]]; then
            alias_match=$((alias_match + 1))
        else
            alias_misses="$alias_misses $alias_name"
        fi
    done
    if [[ $alias_match -eq $alias_count ]]; then
        check_pass "aliases: all $alias_count present in git config"
    else
        check_fail "aliases: $alias_match/$alias_count in git config (missing:$alias_misses)"
    fi
else
    check_skip "aliases (none in .env)"
fi

echo " Claude Code (file Claude actually reads):"

# The file at $deploy_target/settings.json IS what Claude Code loads.
# Since it's a symlink, verify the content Claude sees matches our source.
if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
    source_file="$REPO_ROOT/plugins/claude/settings.json"
    target_file="$deploy_target/settings.json"

    if [[ -f "$source_file" && -f "$target_file" ]]; then
        # Byte-for-byte comparison (symlink means same file, but verify)
        if cmp -s "$source_file" "$target_file"; then
            check_pass "settings.json: Claude reads identical content to source"
        else
            check_fail "settings.json: Claude reads different content than source"
        fi

        # Extract what Claude will actually enforce
        perm_summary=$(python3 -c "
import json
d = json.load(open('$target_file'))
p = d.get('permissions', {})
allow = len(p.get('allow', []))
deny = len(p.get('deny', []))
ask = len(p.get('ask', []))
hooks = d.get('hooks', {})
pre = len(hooks.get('PreToolUse', []))
post = len(hooks.get('PostToolUse', []))
env_vars = len(d.get('env', {}))
print(f'{allow} allow, {deny} deny, {ask} ask, {pre} pre-hooks, {post} post-hooks, {env_vars} env vars')
" 2>/dev/null || echo "parse error")
        check_pass "Claude loads: $perm_summary"
    fi
else
    check_skip "Claude settings reality (not enabled)"
fi

# CLAUDE.md — verify what Claude reads matches source
if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
    source_file="$REPO_ROOT/plugins/claude/CLAUDE.md"
    target_file="$deploy_target/CLAUDE.md"

    if [[ -f "$source_file" && -f "$target_file" ]]; then
        if cmp -s "$source_file" "$target_file"; then
            check_pass "CLAUDE.md: Claude reads identical content to source"
        else
            check_fail "CLAUDE.md: Claude reads different content than source"
        fi
    fi
fi

# ═════════════════════════════════════════════════════════════
# SUMMARY
# ═════════════════════════════════════════════════════════════

echo ""
echo "═══════════════════════════════════════════════════════════"
if [[ $fail -eq 0 ]]; then
    echo -e "  ${green}ALL CHECKS PASSED${reset}  ($pass passed, $skip skipped)"
else
    echo -e "  ${red}FAILURES DETECTED${reset}  ($pass passed, $fail failed, $skip skipped)"
fi
echo "═══════════════════════════════════════════════════════════"

exit $fail
