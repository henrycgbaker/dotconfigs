#!/usr/bin/env bash
# test-project-configs.sh — Non-interactive test for dotconfigs project-configs
#
# Creates a temp git repo, sources the dotconfigs environment, runs
# project-configs for both claude and git plugins, then verifies all
# expected artifacts are created with correct content.
#
# Usage:
#   ./tests/test-project-configs.sh              Run all tests
#   ./tests/test-project-configs.sh --verbose    Show detail on each check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
VERBOSE=false
[[ "${1:-}" == "--verbose" ]] && VERBOSE=true

# ============================================================================
# Test infrastructure
# ============================================================================

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

# ============================================================================
# Set up temp test directory
# ============================================================================

# Find an unused test directory name
TEST_BASE="/tmp/test-dot-claude"
TEST_DIR="$TEST_BASE"
counter=0
while [[ -d "$TEST_DIR" ]]; do
    counter=$((counter + 1))
    TEST_DIR="${TEST_BASE}-${counter}"
done

mkdir -p "$TEST_DIR"

# Clean up on exit
cleanup() {
    if [[ -d "$TEST_DIR" ]]; then
        rm -rf "$TEST_DIR"
    fi
}
trap cleanup EXIT

echo "═══════════════════════════════════════════════════════════"
echo "  dotconfigs project-configs Test Suite"
echo "  Test dir: $TEST_DIR"
echo "═══════════════════════════════════════════════════════════"

# Initialise a git repo in the test dir
git init "$TEST_DIR" > /dev/null 2>&1
git -C "$TEST_DIR" commit --allow-empty -m "initial commit" > /dev/null 2>&1

# ============================================================================
# Create a synthetic .env with representative config
# ============================================================================

# We cannot read the real .env (permission denied), so we create a
# representative one based on .env.example structure.
TEST_ENV_FILE="$TEST_DIR/.test-env"
cat > "$TEST_ENV_FILE" <<'ENVEOF'
DOTCONFIGS_VERSION="2.0"

# Claude plugin config
CLAUDE_DEPLOY_TARGET="$HOME/.claude"
CLAUDE_SETTINGS_ENABLED="true"
CLAUDE_SETTINGS_PYTHON="true"
CLAUDE_SETTINGS_NODE="false"
CLAUDE_MD_SECTIONS="communication simplicity documentation git code-style"
CLAUDE_HOOKS_ENABLED="block-destructive.sh post-tool-format.py"
CLAUDE_SKILLS_ENABLED="commit squash-merge"
CLAUDE_MD_EXCLUDE_GLOBAL="true"
CLAUDE_MD_EXCLUDE_PATTERN="CLAUDE.md"
CLAUDE_MD_EXCLUDE_DEST="exclude"

# Git plugin config
GIT_USER_NAME="Test User"
GIT_USER_EMAIL="test@example.com"
GIT_HOOKS_SCOPE="project"
GIT_HOOK_CONFIG_PATH=".githooks/config"
ENVEOF

# ============================================================================
# Source dotconfigs environment
# ============================================================================

# Source shared libraries (same as the dotconfigs entry point does)
SCRIPT_DIR_SAVE="$SCRIPT_DIR"
SCRIPT_DIR="$REPO_ROOT"
PLUGINS_DIR="$REPO_ROOT/plugins"
ENV_FILE="$TEST_ENV_FILE"

source "$REPO_ROOT/lib/wizard.sh"
source "$REPO_ROOT/lib/symlinks.sh"
source "$REPO_ROOT/lib/discovery.sh"
source "$REPO_ROOT/lib/validation.sh"
source "$REPO_ROOT/lib/colours.sh"
source "$REPO_ROOT/lib/config.sh"

# Load our test .env
source "$TEST_ENV_FILE"

# Restore script dir for test output
SCRIPT_DIR="$SCRIPT_DIR_SAVE"

# ============================================================================
# Run Claude plugin project-configs (non-interactive)
# ============================================================================

section "Running Claude project-configs..."

# Source the plugin (this re-sources real .env if it exists)
source "$REPO_ROOT/plugins/claude/project.sh"
# Re-apply test env to override real .env values
source "$TEST_ENV_FILE"

# Pipe "y" for every wizard_yesno prompt.
# Greenfield project expected prompts:
#   1. Create project-specific settings.json? [Y/n] -> y
#   2. Enable PreToolUse hook? [Y/n] -> y
#   3. Deploy Claude hook configuration file? [Y/n] -> y
#   4. Create project CLAUDE.md from global sections? [Y/n] -> y
#   5. Apply CLAUDE.md exclusion for this project? [Y/n] -> y
#   6. Commit .dotconfigs.json to git? [y/N] -> n  (we want it excluded)
yes_responses=$(printf 'y\ny\ny\ny\ny\nn\n')
echo "$yes_responses" | plugin_claude_project "$TEST_DIR" 2>&1 || true

echo ""

# ============================================================================
# Run Git plugin project-configs (non-interactive)
# ============================================================================

section "Running Git project-configs..."

source "$REPO_ROOT/plugins/git/project.sh"
# Re-apply test env to override real .env values
source "$TEST_ENV_FILE"

# Expected prompts (greenfield -- hooks don't exist yet, no overwrite prompts):
#   1. Configure project-specific git identity? [y/N] -> n
#   2. Deploy hook configuration to .githooks/config? [Y/n] -> y
git_responses=$(printf 'n\ny\n')
echo "$git_responses" | plugin_git_project "$TEST_DIR" 2>&1 || true

echo ""

# ============================================================================
# ASSERTIONS: Claude plugin artifacts
# ============================================================================

section "Claude Plugin Assertions"

# --- .claude/ directory ---
echo " Directory structure:"
if [[ -d "$TEST_DIR/.claude" ]]; then
    check_pass ".claude/ directory exists"
else
    check_fail ".claude/ directory does not exist"
fi

# --- .claude/settings.json ---
echo " Settings:"
if [[ -f "$TEST_DIR/.claude/settings.json" ]]; then
    check_pass ".claude/settings.json exists"

    # Valid JSON
    if python3 -c "import json; json.load(open('$TEST_DIR/.claude/settings.json'))" 2>/dev/null; then
        check_pass ".claude/settings.json is valid JSON"
    else
        check_fail ".claude/settings.json is invalid JSON"
    fi

    # Check it has permissions section (from base.json)
    has_permissions=$(python3 -c "
import json
d = json.load(open('$TEST_DIR/.claude/settings.json'))
print('yes' if 'permissions' in d else 'no')
" 2>/dev/null || echo "error")
    if [[ "$has_permissions" == "yes" ]]; then
        check_pass "settings.json has permissions section"
    else
        check_fail "settings.json missing permissions section"
    fi

    # Check hook paths use .claude/hooks/ not $CLAUDE_PROJECT_DIR
    bad_paths=$(python3 -c "
import json
d = json.load(open('$TEST_DIR/.claude/settings.json'))
bad = []
for event in ('PreToolUse', 'PostToolUse'):
    for h in d.get('hooks', {}).get(event, []):
        cmd = h.get('command', '')
        if '\$CLAUDE_PROJECT_DIR' in cmd or 'plugins/claude/hooks' in cmd:
            bad.append(cmd)
if bad:
    print('BAD: ' + ', '.join(bad))
else:
    print('OK')
" 2>/dev/null || echo "error")
    if [[ "$bad_paths" == "OK" ]]; then
        check_pass "settings.json hook paths use .claude/hooks/ (not source repo paths)"
    else
        check_fail "settings.json has wrong hook paths: $bad_paths"
    fi

    # Check hook paths reference .claude/hooks/ specifically
    has_hooks=$(python3 -c "
import json
d = json.load(open('$TEST_DIR/.claude/settings.json'))
hooks = d.get('hooks', {})
has_pre = len(hooks.get('PreToolUse', [])) > 0
has_post = len(hooks.get('PostToolUse', [])) > 0
print('yes' if has_pre and has_post else 'no')
" 2>/dev/null || echo "error")
    if [[ "$has_hooks" == "yes" ]]; then
        check_pass "settings.json has PreToolUse and PostToolUse hook entries"
    else
        check_fail "settings.json missing hook entries (hooks.json not merged)"
    fi
else
    check_fail ".claude/settings.json does not exist"
fi

# --- .claude/hooks/block-destructive.sh ---
echo " Hooks:"
if [[ -f "$TEST_DIR/.claude/hooks/block-destructive.sh" ]]; then
    check_pass ".claude/hooks/block-destructive.sh exists"
    if [[ -x "$TEST_DIR/.claude/hooks/block-destructive.sh" ]]; then
        check_pass ".claude/hooks/block-destructive.sh is executable"
    else
        check_fail ".claude/hooks/block-destructive.sh is not executable"
    fi
else
    check_fail ".claude/hooks/block-destructive.sh does not exist"
fi

# --- .claude/claude-hooks.conf ---
echo " Hook config:"
if [[ -f "$TEST_DIR/.claude/claude-hooks.conf" ]]; then
    check_pass ".claude/claude-hooks.conf exists"

    # Should contain CLAUDE_HOOK_ settings
    if grep -q "CLAUDE_HOOK_" "$TEST_DIR/.claude/claude-hooks.conf" 2>/dev/null; then
        check_pass "claude-hooks.conf contains CLAUDE_HOOK_ settings"
    else
        check_fail "claude-hooks.conf has no CLAUDE_HOOK_ settings"
    fi
else
    check_fail ".claude/claude-hooks.conf does not exist"
fi

# --- CLAUDE.md ---
echo " CLAUDE.md:"
if [[ -f "$TEST_DIR/CLAUDE.md" ]]; then
    check_pass "CLAUDE.md exists"

    # Non-empty
    if [[ -s "$TEST_DIR/CLAUDE.md" ]]; then
        check_pass "CLAUDE.md is non-empty"
    else
        check_fail "CLAUDE.md is empty"
    fi

    line_count=$(wc -l < "$TEST_DIR/CLAUDE.md" | tr -d ' ')

    # Should contain actual section content from templates, NOT just boilerplate
    # The configured sections are: communication simplicity documentation git code-style
    # Communication template contains "## Communication Style"
    if grep -q "## Communication Style" "$TEST_DIR/CLAUDE.md" 2>/dev/null; then
        check_pass "CLAUDE.md contains Communication Style section (from templates)"
    else
        check_fail "CLAUDE.md missing Communication Style section (likely hardcoded boilerplate instead of template assembly)"
    fi

    # Check for Simplicity section
    if grep -q "## Simplicity" "$TEST_DIR/CLAUDE.md" 2>/dev/null; then
        check_pass "CLAUDE.md contains Simplicity section"
    else
        check_fail "CLAUDE.md missing Simplicity section"
    fi

    # Check for Git section
    if grep -q "## Git" "$TEST_DIR/CLAUDE.md" 2>/dev/null; then
        check_pass "CLAUDE.md contains Git section"
    else
        check_fail "CLAUDE.md missing Git section"
    fi

    # Check for Code Style section
    if grep -q "## Code Style" "$TEST_DIR/CLAUDE.md" 2>/dev/null; then
        check_pass "CLAUDE.md contains Code Style section"
    else
        check_fail "CLAUDE.md missing Code Style section"
    fi

    # Should NOT be the generic boilerplate
    if grep -q "This project uses dotconfigs for Claude Code configuration" "$TEST_DIR/CLAUDE.md" 2>/dev/null; then
        check_fail "CLAUDE.md is generic boilerplate (should be assembled from CLAUDE_MD_SECTIONS templates)"
    else
        check_pass "CLAUDE.md is not generic boilerplate"
    fi

    [[ "$VERBOSE" == "true" ]] && echo "    ($line_count lines in CLAUDE.md)"
else
    check_fail "CLAUDE.md does not exist"
fi

# --- .git/info/exclude ---
echo " Git exclusions:"
exclude_file="$TEST_DIR/.git/info/exclude"
if [[ -f "$exclude_file" ]]; then
    check_pass ".git/info/exclude exists"

    if grep -q "^CLAUDE\.md$" "$exclude_file" 2>/dev/null; then
        check_pass ".git/info/exclude contains CLAUDE.md"
    else
        check_fail ".git/info/exclude missing CLAUDE.md"
    fi

    if grep -q "^\.claude/$" "$exclude_file" 2>/dev/null; then
        check_pass ".git/info/exclude contains .claude/"
    else
        check_fail ".git/info/exclude missing .claude/"
    fi

    if grep -q "^\.dotconfigs\.json$" "$exclude_file" 2>/dev/null; then
        check_pass ".git/info/exclude contains .dotconfigs.json"
    else
        check_fail ".git/info/exclude missing .dotconfigs.json"
    fi
else
    check_fail ".git/info/exclude does not exist"
fi

# --- .dotconfigs.json ---
echo " Project config:"
if [[ -f "$TEST_DIR/.dotconfigs.json" ]]; then
    check_pass ".dotconfigs.json exists"

    # Valid JSON
    if python3 -c "import json; json.load(open('$TEST_DIR/.dotconfigs.json'))" 2>/dev/null; then
        check_pass ".dotconfigs.json is valid JSON"
    else
        check_fail ".dotconfigs.json is invalid JSON"
    fi

    # Contains claude plugin config
    has_claude=$(python3 -c "
import json
d = json.load(open('$TEST_DIR/.dotconfigs.json'))
print('yes' if 'claude' in d.get('plugins', {}) else 'no')
" 2>/dev/null || echo "error")
    if [[ "$has_claude" == "yes" ]]; then
        check_pass ".dotconfigs.json has claude plugin entry"
    else
        check_fail ".dotconfigs.json missing claude plugin entry"
    fi
else
    check_fail ".dotconfigs.json does not exist"
fi

# ============================================================================
# ASSERTIONS: Git plugin artifacts
# ============================================================================

section "Git Plugin Assertions"

# --- .git/hooks/ contains hooks ---
echo " Git hooks:"
hooks_dir="$TEST_DIR/.git/hooks"
expected_hooks="commit-msg pre-commit pre-push prepare-commit-msg post-merge post-checkout post-rewrite"
deployed_count=0
total_expected=0

for hook_name in $expected_hooks; do
    total_expected=$((total_expected + 1))
    if [[ -f "$hooks_dir/$hook_name" ]]; then
        deployed_count=$((deployed_count + 1))
        if [[ -x "$hooks_dir/$hook_name" ]]; then
            check_pass ".git/hooks/$hook_name exists and is executable"
        else
            check_fail ".git/hooks/$hook_name exists but is not executable"
        fi
    else
        check_fail ".git/hooks/$hook_name not found"
    fi
done

# --- Hook config file ---
echo " Hook configuration:"
hook_config_path="${GIT_HOOK_CONFIG_PATH:-.githooks/config}"
config_target="$TEST_DIR/$hook_config_path"

if [[ -f "$config_target" ]]; then
    check_pass "Hook config exists at $hook_config_path"

    # Should contain hook settings
    if grep -q "GIT_HOOK_" "$config_target" 2>/dev/null; then
        check_pass "Hook config contains GIT_HOOK_ settings"
    else
        check_fail "Hook config has no GIT_HOOK_ settings"
    fi
else
    check_fail "Hook config not found at $hook_config_path"
fi

# --- .dotconfigs.json has git plugin entry ---
echo " Git in .dotconfigs.json:"
if [[ -f "$TEST_DIR/.dotconfigs.json" ]]; then
    has_git=$(python3 -c "
import json
d = json.load(open('$TEST_DIR/.dotconfigs.json'))
print('yes' if 'git' in d.get('plugins', {}) else 'no')
" 2>/dev/null || echo "error")
    if [[ "$has_git" == "yes" ]]; then
        check_pass ".dotconfigs.json has git plugin entry"
    else
        check_fail ".dotconfigs.json missing git plugin entry"
    fi
fi

# ============================================================================
# SCENARIO 2: Default responses (all defaults) — .dotconfigs.json excluded
# ============================================================================

section "Scenario 2: Default responses — .dotconfigs.json exclusion"

# Create a second test directory
TEST_DIR2="${TEST_DIR}-defaults"
mkdir -p "$TEST_DIR2"
git init "$TEST_DIR2" > /dev/null 2>&1
git -C "$TEST_DIR2" commit --allow-empty -m "initial commit" > /dev/null 2>&1

# Source plugins fresh
source "$REPO_ROOT/plugins/claude/project.sh"
source "$TEST_ENV_FILE"

# Send all empty responses (accept defaults):
# All wizard_yesno will get "" which falls through to default
# The "Select [1-2]" menu will also get "" and fall to case 2|*
defaults=$(printf '\n\n\n\n\n\n\n\n\n\n')
echo "$defaults" | plugin_claude_project "$TEST_DIR2" 2>&1 || true

echo ""

# Check that .dotconfigs.json is excluded by default
echo " Default scenario assertions:"
defaults_exclude="$TEST_DIR2/.git/info/exclude"
if [[ -f "$defaults_exclude" ]]; then
    if grep -q "^\.dotconfigs\.json$" "$defaults_exclude" 2>/dev/null; then
        check_pass ".dotconfigs.json excluded by default (default=n for commit question)"
    else
        check_fail ".dotconfigs.json NOT excluded when taking defaults (default should be n)"
    fi
else
    check_fail ".git/info/exclude not found in defaults scenario"
fi

# Check .claude-project is NOT in exclusions (removed in favour of .dotconfigs.json)
if grep -q "^\.claude-project$" "$defaults_exclude" 2>/dev/null; then
    check_fail ".claude-project found in exclusions (should have been replaced with .dotconfigs.json)"
else
    check_pass ".claude-project not in exclusions (correctly replaced with .dotconfigs.json)"
fi

# Clean up second test dir
rm -rf "$TEST_DIR2"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "═══════════════════════════════════════════════════════════"
total=$((pass + fail))
if [[ $fail -eq 0 ]]; then
    echo -e "  ${green}ALL CHECKS PASSED${reset}  ($pass passed, $skip skipped)"
else
    echo -e "  ${red}FAILURES DETECTED${reset}  ($pass passed, $fail failed, $skip skipped)"
fi
echo "═══════════════════════════════════════════════════════════"
echo ""

# Show test dir contents for debugging if failures
if [[ $fail -gt 0 && "$VERBOSE" == "true" ]]; then
    echo "Test directory contents:"
    find "$TEST_DIR" -not -path '*/.git/objects/*' -not -path '*/.git/refs/*' | sort | head -50
    echo ""
    if [[ -f "$TEST_DIR/CLAUDE.md" ]]; then
        echo "CLAUDE.md contents:"
        head -20 "$TEST_DIR/CLAUDE.md"
        echo "..."
    fi
    if [[ -f "$TEST_DIR/.claude/settings.json" ]]; then
        echo ""
        echo "settings.json contents:"
        python3 -c "import json; print(json.dumps(json.load(open('$TEST_DIR/.claude/settings.json')), indent=2))" 2>/dev/null || cat "$TEST_DIR/.claude/settings.json"
    fi
fi

exit $fail
