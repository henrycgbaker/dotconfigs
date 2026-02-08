# lib/config.sh — Shared configuration loading for hooks
# Sourced by dotconfigs entry point.
# Provides SSOT variable naming documentation and config resolution helpers.

# ============================================================================
# HOOK CONFIGURATION VARIABLES - SINGLE SOURCE OF TRUTH
# ============================================================================
#
# This file documents all hook configuration variables across both plugins.
# Hooks themselves use inline config loading (they cannot source this file
# from .git/hooks/), but this serves as the authoritative reference for:
# - Variable naming conventions
# - Default values
# - Config hierarchy (hardcoded → env var → config file)
#
# NAMING CONVENTION:
# - Git hook settings: GIT_HOOK_* prefix
# - Claude hook settings: CLAUDE_HOOK_* prefix
# - Boolean settings: "true"/"false" string values
# - Per-hook enable/disable: {PREFIX}_ENABLED suffix
#
# CONFIG HIERARCHY (lowest to highest precedence):
# 1. Hardcoded defaults (documented below)
# 2. Environment variables (set in .env or shell)
# 3. Project config file (sourced by hooks at runtime)
#
# ============================================================================

# ----------------------------------------------------------------------------
# GIT HOOKS - commit-msg
# ----------------------------------------------------------------------------
# GIT_HOOK_BLOCK_AI_ATTRIBUTION=true        Block AI attribution in commits
# GIT_HOOK_WIP_BLOCK_ON_MAIN=true           Block WIP commits on main branch
# GIT_HOOK_CONVENTIONAL_COMMITS=true        Enable conventional commit validation
# GIT_HOOK_CONVENTIONAL_COMMITS_STRICT=false Enforce conventional (vs warn)
# GIT_HOOK_MAX_SUBJECT_LENGTH=72            Maximum subject line length
# GIT_HOOK_COMMIT_MSG_ENABLED=true          Enable commit-msg hook

# ----------------------------------------------------------------------------
# GIT HOOKS - pre-push
# ----------------------------------------------------------------------------
# GIT_HOOK_BRANCH_PROTECTION=warn           Protect main/master (block/warn/off)
# GIT_HOOK_PRE_PUSH_ENABLED=true            Enable pre-push hook

# ----------------------------------------------------------------------------
# GIT HOOKS - pre-commit (future)
# ----------------------------------------------------------------------------
# GIT_HOOK_SECRETS_CHECK=true               Check for secrets in staged files
# GIT_HOOK_LARGE_FILE_CHECK=true            Check for large files
# GIT_HOOK_LARGE_FILE_THRESHOLD=1048576     Large file size threshold (bytes)
# GIT_HOOK_DEBUG_CHECK=true                 Check for debug statements
# GIT_HOOK_DEBUG_CHECK_STRICT=false         Block vs warn on debug statements
# GIT_HOOK_PRE_COMMIT_ENABLED=true          Enable pre-commit hook

# ----------------------------------------------------------------------------
# GIT HOOKS - prepare-commit-msg (future)
# ----------------------------------------------------------------------------
# GIT_HOOK_BRANCH_PREFIX=true               Auto-prefix commit with branch name
# GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED=true  Enable prepare-commit-msg hook

# ----------------------------------------------------------------------------
# GIT HOOKS - post-merge (future)
# ----------------------------------------------------------------------------
# GIT_HOOK_DEPENDENCY_CHECK=true            Check for dependency changes
# GIT_HOOK_MIGRATION_REMINDER=true          Remind about pending migrations
# GIT_HOOK_POST_MERGE_ENABLED=true          Enable post-merge hook

# ----------------------------------------------------------------------------
# GIT HOOKS - post-checkout (future)
# ----------------------------------------------------------------------------
# GIT_HOOK_BRANCH_INFO=true                 Display branch info on checkout
# GIT_HOOK_POST_CHECKOUT_ENABLED=true       Enable post-checkout hook

# ----------------------------------------------------------------------------
# GIT HOOKS - post-rewrite (future)
# ----------------------------------------------------------------------------
# GIT_HOOK_POST_REWRITE_ENABLED=true        Enable post-rewrite hook

# ----------------------------------------------------------------------------
# CLAUDE HOOKS
# ----------------------------------------------------------------------------
# CLAUDE_HOOK_DESTRUCTIVE_GUARD=true        Guard against destructive commands
# CLAUDE_HOOK_FILE_PROTECTION=true          Protect critical files
# CLAUDE_HOOK_RUFF_FORMAT=true              Auto-format Python with Ruff

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

# Resolve a single config variable using hierarchy
# Args: var_name, config_file_path, default_value
# Returns: resolved value (prints to stdout)
_config_resolve() {
    local var_name="$1"
    local config_file="$2"
    local default_value="$3"
    local resolved_value=""

    # Start with default
    resolved_value="$default_value"

    # Check environment variable (overrides default)
    if [[ -n "${!var_name:-}" ]]; then
        resolved_value="${!var_name}"
    fi

    # Check config file (overrides env var)
    if [[ -f "$config_file" ]]; then
        # Source config file in subshell to avoid polluting environment
        local file_value
        file_value=$(source "$config_file" 2>/dev/null && echo "${!var_name:-}")
        if [[ -n "$file_value" ]]; then
            resolved_value="$file_value"
        fi
    fi

    echo "$resolved_value"
}

# Load git hook configuration with standard hierarchy
# Args: config_file_path
# Sets: All GIT_HOOK_* variables in current shell
# Note: This is a helper for setup/deploy scripts, not for hooks themselves
load_git_hook_config() {
    local config_file="${1:-}"

    # Set defaults first
    GIT_HOOK_BLOCK_AI_ATTRIBUTION="${GIT_HOOK_BLOCK_AI_ATTRIBUTION:-true}"
    GIT_HOOK_WIP_BLOCK_ON_MAIN="${GIT_HOOK_WIP_BLOCK_ON_MAIN:-true}"
    GIT_HOOK_CONVENTIONAL_COMMITS="${GIT_HOOK_CONVENTIONAL_COMMITS:-true}"
    GIT_HOOK_CONVENTIONAL_COMMITS_STRICT="${GIT_HOOK_CONVENTIONAL_COMMITS_STRICT:-false}"
    GIT_HOOK_MAX_SUBJECT_LENGTH="${GIT_HOOK_MAX_SUBJECT_LENGTH:-72}"
    GIT_HOOK_COMMIT_MSG_ENABLED="${GIT_HOOK_COMMIT_MSG_ENABLED:-true}"

    GIT_HOOK_BRANCH_PROTECTION="${GIT_HOOK_BRANCH_PROTECTION:-warn}"
    GIT_HOOK_PRE_PUSH_ENABLED="${GIT_HOOK_PRE_PUSH_ENABLED:-true}"

    GIT_HOOK_SECRETS_CHECK="${GIT_HOOK_SECRETS_CHECK:-true}"
    GIT_HOOK_LARGE_FILE_CHECK="${GIT_HOOK_LARGE_FILE_CHECK:-true}"
    GIT_HOOK_LARGE_FILE_THRESHOLD="${GIT_HOOK_LARGE_FILE_THRESHOLD:-1048576}"
    GIT_HOOK_DEBUG_CHECK="${GIT_HOOK_DEBUG_CHECK:-true}"
    GIT_HOOK_DEBUG_CHECK_STRICT="${GIT_HOOK_DEBUG_CHECK_STRICT:-false}"
    GIT_HOOK_PRE_COMMIT_ENABLED="${GIT_HOOK_PRE_COMMIT_ENABLED:-true}"

    GIT_HOOK_BRANCH_PREFIX="${GIT_HOOK_BRANCH_PREFIX:-true}"
    GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED="${GIT_HOOK_PREPARE_COMMIT_MSG_ENABLED:-true}"

    GIT_HOOK_DEPENDENCY_CHECK="${GIT_HOOK_DEPENDENCY_CHECK:-true}"
    GIT_HOOK_MIGRATION_REMINDER="${GIT_HOOK_MIGRATION_REMINDER:-true}"
    GIT_HOOK_POST_MERGE_ENABLED="${GIT_HOOK_POST_MERGE_ENABLED:-true}"

    GIT_HOOK_BRANCH_INFO="${GIT_HOOK_BRANCH_INFO:-true}"
    GIT_HOOK_POST_CHECKOUT_ENABLED="${GIT_HOOK_POST_CHECKOUT_ENABLED:-true}"

    GIT_HOOK_POST_REWRITE_ENABLED="${GIT_HOOK_POST_REWRITE_ENABLED:-true}"

    # Load config file if provided and exists (overrides env vars)
    if [[ -n "$config_file" && -f "$config_file" ]]; then
        source "$config_file"
    fi
}
