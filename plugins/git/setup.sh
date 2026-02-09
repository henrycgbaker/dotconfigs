# plugins/git/setup.sh — Git configuration setup wizard
# Sourced by dotconfigs entry point. Do not execute directly.

# Internal helper: Check if value is in space-separated list
_is_in_list() {
    local needle="$1"
    local haystack="$2"

    for item in $haystack; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

# Internal: Identity section wizard (opt-in model)
_git_wizard_identity() {
    wizard_header 1 "Identity"
    echo "Configure git user.name and user.email (applied globally)"
    echo ""

    # Pre-fill from .env, fall back to git config
    local default_name="${GIT_USER_NAME:-}"
    if [[ -z "$default_name" ]]; then
        default_name="$(git config --global --get user.name 2>/dev/null || echo "")"
    fi

    local default_email="${GIT_USER_EMAIL:-}"
    if [[ -z "$default_email" ]]; then
        default_email="$(git config --global --get user.email 2>/dev/null || echo "")"
    fi

    wizard_prompt "Git user.name" "$default_name" GIT_USER_NAME
    wizard_prompt "Git user.email" "$default_email" GIT_USER_EMAIL
}

# Internal: Workflow settings section wizard (opt-in model)
_git_wizard_workflow() {
    wizard_header 2 "Workflow Settings"
    echo "Configure git workflow preferences"
    echo ""

    echo "Select which workflow settings to manage (opinionated defaults pre-filled):"
    echo ""

    # Core settings
    local pull_rebase_default="${GIT_PULL_REBASE:-true}"
    local manage_default="n"
    [[ -n "${GIT_PULL_REBASE:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage pull.rebase?" "$manage_default"; then
        wizard_prompt "    pull.rebase" "$pull_rebase_default" GIT_PULL_REBASE
    else
        unset GIT_PULL_REBASE
    fi

    local push_default_default="${GIT_PUSH_DEFAULT:-simple}"
    manage_default="n"
    [[ -n "${GIT_PUSH_DEFAULT:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage push.default?" "$manage_default"; then
        wizard_prompt "    push.default" "$push_default_default" GIT_PUSH_DEFAULT
    else
        unset GIT_PUSH_DEFAULT
    fi

    local fetch_prune_default="${GIT_FETCH_PRUNE:-true}"
    manage_default="n"
    [[ -n "${GIT_FETCH_PRUNE:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage fetch.prune?" "$manage_default"; then
        wizard_prompt "    fetch.prune" "$fetch_prune_default" GIT_FETCH_PRUNE
    else
        unset GIT_FETCH_PRUNE
    fi

    local default_branch="${GIT_INIT_DEFAULT_BRANCH:-main}"
    manage_default="n"
    [[ -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage init.defaultBranch?" "$manage_default"; then
        wizard_prompt "    init.defaultBranch" "$default_branch" GIT_INIT_DEFAULT_BRANCH
    else
        unset GIT_INIT_DEFAULT_BRANCH
    fi

    echo ""
    echo "Advanced settings (opt-in):"
    echo ""

    local rerere_default="${GIT_RERERE_ENABLED:-false}"
    manage_default="n"
    [[ -n "${GIT_RERERE_ENABLED:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage rerere.enabled? (reuse conflict resolutions)" "$manage_default"; then
        wizard_prompt "    rerere.enabled" "$rerere_default" GIT_RERERE_ENABLED
    else
        unset GIT_RERERE_ENABLED
    fi

    local diff_algo_default="${GIT_DIFF_ALGORITHM:-}"
    manage_default="n"
    [[ -n "${GIT_DIFF_ALGORITHM:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage diff.algorithm? (better diff output)" "$manage_default"; then
        wizard_prompt "    diff.algorithm" "${diff_algo_default:-histogram}" GIT_DIFF_ALGORITHM
    else
        unset GIT_DIFF_ALGORITHM
    fi

    local autocorrect_default="${GIT_HELP_AUTOCORRECT:-}"
    manage_default="n"
    [[ -n "${GIT_HELP_AUTOCORRECT:-}" ]] && manage_default="y"
    if wizard_yesno "  Manage help.autocorrect? (auto-run typo corrections)" "$manage_default"; then
        wizard_prompt "    help.autocorrect (deciseconds)" "${autocorrect_default:-10}" GIT_HELP_AUTOCORRECT
    else
        unset GIT_HELP_AUTOCORRECT
    fi
}

# Internal: Aliases section wizard (opt-in model)
_git_wizard_aliases() {
    wizard_header 3 "Aliases"
    echo "Add git command aliases"
    echo ""

    # Default aliases with definitions
    local default_alias_unstage="reset HEAD --"
    local default_alias_last="log -1 HEAD"
    local default_alias_lg="log --oneline --graph --all --decorate"
    local default_alias_amend="commit --amend --no-edit"
    local default_alias_undo="reset HEAD~1 --mixed"
    local default_alias_wip="commit -am \"WIP\""

    # Pre-fill enabled list from .env
    local enabled_list="${GIT_ALIASES_ENABLED:-}"
    local alias_names=(unstage last lg amend undo wip)
    local enabled_names=""

    echo "Default aliases (select which to add):"
    echo ""

    for alias_name in "${alias_names[@]}"; do
        local alias_var="default_alias_${alias_name}"
        local alias_cmd="${!alias_var}"
        local alias_default="n"

        # Check if this alias was previously enabled
        if _is_in_list "$alias_name" "$enabled_list"; then
            alias_default="y"
        fi

        if wizard_yesno "  $alias_name = $alias_cmd" "$alias_default"; then
            enabled_names="$enabled_names $alias_name"
            # Store alias definition
            local alias_key="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"
            eval "${alias_key}=\"${alias_cmd}\""
        fi
    done

    # Custom aliases
    echo ""
    if wizard_yesno "Add custom aliases?" "n"; then
        echo ""
        echo "Enter custom aliases (leave name empty to finish)"
        echo ""

        # Git built-in commands blacklist
        local GIT_BUILTIN_COMMANDS=(
            commit push pull fetch merge rebase checkout switch branch
            status log diff add rm mv reset tag stash clone init remote
            show bisect grep blame
        )

        while true; do
            local custom_name=""
            read -p "Alias name: " custom_name
            [[ -z "$custom_name" ]] && break

            # Validate against built-in commands
            local is_builtin=0
            for cmd in "${GIT_BUILTIN_COMMANDS[@]}"; do
                if [[ "$custom_name" == "$cmd" ]]; then
                    echo "Cannot create alias '$custom_name' -- conflicts with git built-in command" >&2
                    is_builtin=1
                    break
                fi
            done
            [[ $is_builtin -eq 1 ]] && continue

            local custom_cmd=""
            read -p "Alias command: " custom_cmd
            [[ -z "$custom_cmd" ]] && continue

            # Store custom alias
            enabled_names="$enabled_names $custom_name"
            local alias_key="GIT_ALIAS_$(echo "$custom_name" | tr '[:lower:]' '[:upper:]')"
            eval "${alias_key}=\"${custom_cmd}\""
        done
    fi

    # Trim leading space and store enabled list
    GIT_ALIASES_ENABLED="${enabled_names# }"
}

# Internal: Hooks section wizard (opt-in model)
_git_wizard_hooks() {
    wizard_header 4 "Hooks"
    echo "Configure git hook preferences"
    echo ""

    # Hooks scope
    local scope_default="y"
    [[ "${GIT_HOOKS_SCOPE:-project}" == "global" ]] && scope_default="n"
    if wizard_yesno "Deploy hooks per-project (recommended)?" "$scope_default"; then
        GIT_HOOKS_SCOPE="project"
    else
        GIT_HOOKS_SCOPE="global"
        echo ""
        echo "Note: Global hooks via core.hooksPath override ALL per-project hooks in .git/hooks/"
        echo "This affects Husky, pre-commit framework, and any project-specific hooks."
        echo ""
    fi

    # Config file location (only for project scope) - REPLACE SELECT LOOP
    if [[ "$GIT_HOOKS_SCOPE" == "project" ]]; then
        echo ""
        echo "Hook config file location:"
        echo "  1) .githooks/config"
        echo "  2) .claude/git-hooks.conf"
        echo "  3) .git/hooks/hooks.conf"
        echo "  4) Custom path"
        echo ""

        local config_default="${GIT_HOOK_CONFIG_PATH:-.githooks/config}"
        local config_choice=""
        read -p "Select [1-4, default: 1]: " config_choice

        case "$config_choice" in
            1|"")
                GIT_HOOK_CONFIG_PATH=".githooks/config"
                ;;
            2)
                GIT_HOOK_CONFIG_PATH=".claude/git-hooks.conf"
                ;;
            3)
                GIT_HOOK_CONFIG_PATH=".git/hooks/hooks.conf"
                ;;
            4)
                read -p "Enter custom path: " GIT_HOOK_CONFIG_PATH
                [[ -z "$GIT_HOOK_CONFIG_PATH" ]] && GIT_HOOK_CONFIG_PATH="$config_default"
                ;;
            *)
                echo "Invalid choice, using default: .githooks/config"
                GIT_HOOK_CONFIG_PATH=".githooks/config"
                ;;
        esac
    fi

    # Hook roster - Pre-commit checks
    echo ""
    echo "Pre-commit checks (run before commit creation):"
    echo ""

    local secrets_default="y"
    [[ "${GIT_HOOK_SECRETS_CHECK:-true}" == "false" ]] && secrets_default="n"
    if wizard_yesno "  Secrets detection (blocks on API keys, private keys)" "$secrets_default"; then
        GIT_HOOK_SECRETS_CHECK="true"
    else
        GIT_HOOK_SECRETS_CHECK="false"
    fi

    local large_file_default="y"
    [[ "${GIT_HOOK_LARGE_FILE_CHECK:-true}" == "false" ]] && large_file_default="n"
    if wizard_yesno "  Large file warning (warns on files >1MB)" "$large_file_default"; then
        GIT_HOOK_LARGE_FILE_CHECK="true"
    else
        GIT_HOOK_LARGE_FILE_CHECK="false"
    fi

    local debug_default="y"
    [[ "${GIT_HOOK_DEBUG_CHECK:-true}" == "false" ]] && debug_default="n"
    if wizard_yesno "  Debug statement detection (console.log, pdb, etc.)" "$debug_default"; then
        GIT_HOOK_DEBUG_CHECK="true"
    else
        GIT_HOOK_DEBUG_CHECK="false"
    fi

    # Hook roster - Commit message
    echo ""
    echo "Commit message validation:"
    echo ""

    local ai_attribution_default="y"
    [[ "${GIT_HOOK_BLOCK_AI_ATTRIBUTION:-true}" == "false" ]] && ai_attribution_default="n"
    if wizard_yesno "  Block AI attribution (e.g. 'Co-authored-by: Claude')" "$ai_attribution_default"; then
        GIT_HOOK_BLOCK_AI_ATTRIBUTION="true"
    else
        GIT_HOOK_BLOCK_AI_ATTRIBUTION="false"
    fi

    local wip_default="y"
    [[ "${GIT_HOOK_WIP_BLOCK_ON_MAIN:-true}" == "false" ]] && wip_default="n"
    if wizard_yesno "  Block WIP commits on main branch" "$wip_default"; then
        GIT_HOOK_WIP_BLOCK_ON_MAIN="true"
    else
        GIT_HOOK_WIP_BLOCK_ON_MAIN="false"
    fi

    local conventional_default="y"
    [[ "${GIT_HOOK_CONVENTIONAL_COMMITS:-true}" == "false" ]] && conventional_default="n"
    if wizard_yesno "  Conventional commit format (feat:, fix:, etc.)" "$conventional_default"; then
        GIT_HOOK_CONVENTIONAL_COMMITS="true"
    else
        GIT_HOOK_CONVENTIONAL_COMMITS="false"
    fi

    # Hook roster - Pre-push - REPLACE SELECT LOOP
    echo ""
    echo "Pre-push protection:"
    echo "  1) warn  — show warning but allow push"
    echo "  2) block — prevent force-push to main/master"
    echo "  3) off   — no pre-push checks"
    echo ""

    local protection_default="${GIT_HOOK_BRANCH_PROTECTION:-warn}"
    local protection_choice=""
    read -p "Select [1-3, default: 1]: " protection_choice

    case "$protection_choice" in
        1|"")
            GIT_HOOK_BRANCH_PROTECTION="warn"
            ;;
        2)
            GIT_HOOK_BRANCH_PROTECTION="block"
            ;;
        3)
            GIT_HOOK_BRANCH_PROTECTION="off"
            ;;
        *)
            echo "Invalid choice, using default: warn"
            GIT_HOOK_BRANCH_PROTECTION="warn"
            ;;
    esac

    # Hook roster - Prepare commit message
    echo ""
    local branch_prefix_default="y"
    [[ "${GIT_HOOK_BRANCH_PREFIX:-true}" == "false" ]] && branch_prefix_default="n"
    if wizard_yesno "Auto-prefix commit with branch name (feature/* -> feat:)?" "$branch_prefix_default"; then
        GIT_HOOK_BRANCH_PREFIX="true"
    else
        GIT_HOOK_BRANCH_PREFIX="false"
    fi

    # Hook roster - Post-merge/rewrite
    echo ""
    echo "Post-merge/rebase helpers (informational only):"
    echo ""

    local dependency_default="y"
    [[ "${GIT_HOOK_DEPENDENCY_CHECK:-true}" == "false" ]] && dependency_default="n"
    if wizard_yesno "  Dependency change detection (package.json, requirements.txt)" "$dependency_default"; then
        GIT_HOOK_DEPENDENCY_CHECK="true"
    else
        GIT_HOOK_DEPENDENCY_CHECK="false"
    fi

    local migration_default="y"
    [[ "${GIT_HOOK_MIGRATION_REMINDER:-true}" == "false" ]] && migration_default="n"
    if wizard_yesno "  Migration reminder (db/migrate/, migrations/)" "$migration_default"; then
        GIT_HOOK_MIGRATION_REMINDER="true"
    else
        GIT_HOOK_MIGRATION_REMINDER="false"
    fi

    # Hook roster - Post-checkout
    echo ""
    local branch_info_default="y"
    [[ "${GIT_HOOK_BRANCH_INFO:-true}" == "false" ]] && branch_info_default="n"
    if wizard_yesno "Branch info on checkout?" "$branch_info_default"; then
        GIT_HOOK_BRANCH_INFO="true"
    else
        GIT_HOOK_BRANCH_INFO="false"
    fi

    # Advanced settings submenu
    echo ""
    if wizard_yesno "Configure advanced settings?" "n"; then
        echo ""
        echo "Advanced settings:"
        echo ""

        local strict_conventional_default="n"
        [[ "${GIT_HOOK_CONVENTIONAL_COMMITS_STRICT:-false}" == "true" ]] && strict_conventional_default="y"
        if wizard_yesno "  Strict conventional commits (block instead of warn)?" "$strict_conventional_default"; then
            GIT_HOOK_CONVENTIONAL_COMMITS_STRICT="true"
        else
            GIT_HOOK_CONVENTIONAL_COMMITS_STRICT="false"
        fi

        local strict_debug_default="n"
        [[ "${GIT_HOOK_DEBUG_CHECK_STRICT:-false}" == "true" ]] && strict_debug_default="y"
        if wizard_yesno "  Strict debug check (block instead of warn)?" "$strict_debug_default"; then
            GIT_HOOK_DEBUG_CHECK_STRICT="true"
        else
            GIT_HOOK_DEBUG_CHECK_STRICT="false"
        fi

        local threshold_default="${GIT_HOOK_LARGE_FILE_THRESHOLD:-1048576}"
        wizard_prompt "  Large file threshold (bytes)" "$threshold_default" GIT_HOOK_LARGE_FILE_THRESHOLD

        local max_subject_default="${GIT_HOOK_MAX_SUBJECT_LENGTH:-72}"
        wizard_prompt "  Max subject line length" "$max_subject_default" GIT_HOOK_MAX_SUBJECT_LENGTH
    fi
}

# Internal: Show edit mode menu for reconfiguration
_git_wizard_edit_mode() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Edit Mode — Current Configuration"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Select categories to reconfigure:"
    echo ""

    # Show current state
    local identity_status="[not managed]"
    [[ -n "${GIT_USER_NAME:-}" ]] && identity_status="configured"

    local workflow_status="[not managed]"
    [[ -n "${GIT_PULL_REBASE:-}" ]] && workflow_status="configured"

    local aliases_status="[not managed]"
    [[ -n "${GIT_ALIASES_ENABLED:-}" ]] && aliases_status="configured"

    local hooks_status="[not managed]"
    [[ -n "${GIT_HOOKS_SCOPE:-}" ]] && hooks_status="configured"

    echo "  1) Identity           — $identity_status"
    echo "  2) Workflow Settings  — $workflow_status"
    echo "  3) Aliases            — $aliases_status"
    echo "  4) Hooks              — $hooks_status"
    echo "  5) Reconfigure all"
    echo "  6) Keep current and exit"
    echo ""
}

# Internal: Display summary (shows managed vs not managed)
_git_wizard_summary() {
    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Configuration Summary"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Identity
    echo "Identity:"
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        echo "  user.name:  $GIT_USER_NAME"
        echo "  user.email: ${GIT_USER_EMAIL:-[not managed]}"
    else
        echo "  [not managed]"
    fi
    echo ""

    # Workflow
    echo "Workflow:"
    if [[ -n "${GIT_PULL_REBASE:-}" || -n "${GIT_PUSH_DEFAULT:-}" || -n "${GIT_FETCH_PRUNE:-}" || -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]]; then
        echo "  pull.rebase:         ${GIT_PULL_REBASE:-[not managed]}"
        echo "  push.default:        ${GIT_PUSH_DEFAULT:-[not managed]}"
        echo "  fetch.prune:         ${GIT_FETCH_PRUNE:-[not managed]}"
        echo "  init.defaultBranch:  ${GIT_INIT_DEFAULT_BRANCH:-[not managed]}"
        echo "  rerere.enabled:      ${GIT_RERERE_ENABLED:-[not managed]}"
        echo "  diff.algorithm:      ${GIT_DIFF_ALGORITHM:-[not managed]}"
        echo "  help.autocorrect:    ${GIT_HELP_AUTOCORRECT:-[not managed]}"
    else
        echo "  [not managed]"
    fi
    echo ""

    # Aliases
    echo "Aliases:"
    if [[ -n "${GIT_ALIASES_ENABLED:-}" ]]; then
        echo "  Enabled: $GIT_ALIASES_ENABLED"
    else
        echo "  [not managed]"
    fi
    echo ""

    # Hooks
    echo "Hooks:"
    if [[ -n "${GIT_HOOKS_SCOPE:-}" ]]; then
        echo "  Scope:                    $GIT_HOOKS_SCOPE"
        [[ -n "${GIT_HOOK_CONFIG_PATH:-}" ]] && echo "  Config path:              $GIT_HOOK_CONFIG_PATH"
        echo "  Secrets check:            ${GIT_HOOK_SECRETS_CHECK:-[not managed]}"
        echo "  Large file check:         ${GIT_HOOK_LARGE_FILE_CHECK:-[not managed]}"
        echo "  Debug check:              ${GIT_HOOK_DEBUG_CHECK:-[not managed]}"
        echo "  Block AI attribution:     ${GIT_HOOK_BLOCK_AI_ATTRIBUTION:-[not managed]}"
        echo "  Block WIP on main:        ${GIT_HOOK_WIP_BLOCK_ON_MAIN:-[not managed]}"
        echo "  Conventional commits:     ${GIT_HOOK_CONVENTIONAL_COMMITS:-[not managed]}"
        echo "  Branch protection:        ${GIT_HOOK_BRANCH_PROTECTION:-[not managed]}"
        echo "  Branch prefix:            ${GIT_HOOK_BRANCH_PREFIX:-[not managed]}"
        echo "  Dependency check:         ${GIT_HOOK_DEPENDENCY_CHECK:-[not managed]}"
        echo "  Migration reminder:       ${GIT_HOOK_MIGRATION_REMINDER:-[not managed]}"
        echo "  Branch info:              ${GIT_HOOK_BRANCH_INFO:-[not managed]}"
    else
        echo "  [not managed]"
    fi
    echo ""
}

# Internal: Save all opted-in GIT_* config to .env
_git_save_config() {
    local env_file="$1"

    # Ensure .env exists with header
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" <<'EOF'
# dotconfigs configuration
# Generated by: dotconfigs global-configs git
# Re-run wizard: dotconfigs global-configs git

EOF
    fi

    # Save identity (only if set)
    [[ -n "${GIT_USER_NAME:-}" ]] && wizard_save_env "$env_file" "GIT_USER_NAME" "$GIT_USER_NAME"
    [[ -n "${GIT_USER_EMAIL:-}" ]] && wizard_save_env "$env_file" "GIT_USER_EMAIL" "$GIT_USER_EMAIL"

    # Save workflow settings (only if set)
    [[ -n "${GIT_PULL_REBASE:-}" ]] && wizard_save_env "$env_file" "GIT_PULL_REBASE" "$GIT_PULL_REBASE"
    [[ -n "${GIT_PUSH_DEFAULT:-}" ]] && wizard_save_env "$env_file" "GIT_PUSH_DEFAULT" "$GIT_PUSH_DEFAULT"
    [[ -n "${GIT_FETCH_PRUNE:-}" ]] && wizard_save_env "$env_file" "GIT_FETCH_PRUNE" "$GIT_FETCH_PRUNE"
    [[ -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]] && wizard_save_env "$env_file" "GIT_INIT_DEFAULT_BRANCH" "$GIT_INIT_DEFAULT_BRANCH"
    [[ -n "${GIT_RERERE_ENABLED:-}" ]] && wizard_save_env "$env_file" "GIT_RERERE_ENABLED" "$GIT_RERERE_ENABLED"
    [[ -n "${GIT_DIFF_ALGORITHM:-}" ]] && wizard_save_env "$env_file" "GIT_DIFF_ALGORITHM" "$GIT_DIFF_ALGORITHM"
    [[ -n "${GIT_HELP_AUTOCORRECT:-}" ]] && wizard_save_env "$env_file" "GIT_HELP_AUTOCORRECT" "$GIT_HELP_AUTOCORRECT"

    # Save aliases enabled list (only if set)
    [[ -n "${GIT_ALIASES_ENABLED:-}" ]] && wizard_save_env "$env_file" "GIT_ALIASES_ENABLED" "$GIT_ALIASES_ENABLED"

    # Save individual alias definitions
    for alias_name in ${GIT_ALIASES_ENABLED:-}; do
        local alias_key="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"
        local alias_value="${!alias_key}"
        [[ -n "$alias_value" ]] && wizard_save_env "$env_file" "$alias_key" "$alias_value"
    done

    # Save hooks settings (only if set)
    [[ -n "${GIT_HOOKS_SCOPE:-}" ]] && wizard_save_env "$env_file" "GIT_HOOKS_SCOPE" "$GIT_HOOKS_SCOPE"
    [[ -n "${GIT_HOOK_CONFIG_PATH:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_CONFIG_PATH" "$GIT_HOOK_CONFIG_PATH"

    # Save hook toggles (only if set)
    [[ -n "${GIT_HOOK_SECRETS_CHECK:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_SECRETS_CHECK" "$GIT_HOOK_SECRETS_CHECK"
    [[ -n "${GIT_HOOK_LARGE_FILE_CHECK:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_LARGE_FILE_CHECK" "$GIT_HOOK_LARGE_FILE_CHECK"
    [[ -n "${GIT_HOOK_DEBUG_CHECK:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_DEBUG_CHECK" "$GIT_HOOK_DEBUG_CHECK"
    [[ -n "${GIT_HOOK_BLOCK_AI_ATTRIBUTION:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_BLOCK_AI_ATTRIBUTION" "$GIT_HOOK_BLOCK_AI_ATTRIBUTION"
    [[ -n "${GIT_HOOK_WIP_BLOCK_ON_MAIN:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_WIP_BLOCK_ON_MAIN" "$GIT_HOOK_WIP_BLOCK_ON_MAIN"
    [[ -n "${GIT_HOOK_CONVENTIONAL_COMMITS:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_CONVENTIONAL_COMMITS" "$GIT_HOOK_CONVENTIONAL_COMMITS"
    [[ -n "${GIT_HOOK_BRANCH_PROTECTION:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_BRANCH_PROTECTION" "$GIT_HOOK_BRANCH_PROTECTION"
    [[ -n "${GIT_HOOK_BRANCH_PREFIX:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_BRANCH_PREFIX" "$GIT_HOOK_BRANCH_PREFIX"
    [[ -n "${GIT_HOOK_DEPENDENCY_CHECK:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_DEPENDENCY_CHECK" "$GIT_HOOK_DEPENDENCY_CHECK"
    [[ -n "${GIT_HOOK_MIGRATION_REMINDER:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_MIGRATION_REMINDER" "$GIT_HOOK_MIGRATION_REMINDER"
    [[ -n "${GIT_HOOK_BRANCH_INFO:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_BRANCH_INFO" "$GIT_HOOK_BRANCH_INFO"

    # Save advanced settings if configured
    [[ -n "${GIT_HOOK_CONVENTIONAL_COMMITS_STRICT:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_CONVENTIONAL_COMMITS_STRICT" "$GIT_HOOK_CONVENTIONAL_COMMITS_STRICT"
    [[ -n "${GIT_HOOK_DEBUG_CHECK_STRICT:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_DEBUG_CHECK_STRICT" "$GIT_HOOK_DEBUG_CHECK_STRICT"
    [[ -n "${GIT_HOOK_LARGE_FILE_THRESHOLD:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_LARGE_FILE_THRESHOLD" "$GIT_HOOK_LARGE_FILE_THRESHOLD"
    [[ -n "${GIT_HOOK_MAX_SUBJECT_LENGTH:-}" ]] && wizard_save_env "$env_file" "GIT_HOOK_MAX_SUBJECT_LENGTH" "$GIT_HOOK_MAX_SUBJECT_LENGTH"
}

# Main entry point — called by dotconfigs CLI
plugin_git_setup() {
    # Derive plugin directory from script location
    local PLUGIN_DIR
    PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    # Determine .env location (repo root)
    local REPO_ROOT
    REPO_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
    local ENV_FILE="$REPO_ROOT/.env"

    # Load existing .env for pre-fill defaults
    if [[ -f "$ENV_FILE" ]]; then
        source "$ENV_FILE"
    fi

    # Initialise colours
    init_colours 2>/dev/null || true

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║               dotconfigs — Git Configuration               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Detect edit mode (re-run when .env has GIT_* keys)
    local is_edit_mode=0
    if [[ -n "${GIT_USER_NAME:-}" || -n "${GIT_PULL_REBASE:-}" || -n "${GIT_HOOKS_SCOPE:-}" ]]; then
        is_edit_mode=1
    fi

    # Edit mode or first-run mode
    if [[ $is_edit_mode -eq 1 ]]; then
        # Edit mode: show current state and let user pick categories to edit
        _git_wizard_edit_mode

        local edit_choice=""
        read -p "Select option [1-6]: " edit_choice

        case "$edit_choice" in
            1)
                _git_wizard_identity
                ;;
            2)
                _git_wizard_workflow
                ;;
            3)
                _git_wizard_aliases
                ;;
            4)
                _git_wizard_hooks
                ;;
            5)
                _git_wizard_identity
                _git_wizard_workflow
                _git_wizard_aliases
                _git_wizard_hooks
                ;;
            6|"")
                echo ""
                echo "No changes made. Current configuration preserved."
                return 0
                ;;
            *)
                echo "Invalid selection. No changes made." >&2
                return 1
                ;;
        esac
    else
        # First-run mode: show category menu
        while true; do
            echo ""
            echo "═══════════════════════════════════════════════════════════"
            echo "  Category Menu"
            echo "═══════════════════════════════════════════════════════════"
            echo ""
            echo "  1) Identity"
            echo "  2) Workflow Settings"
            echo "  3) Aliases"
            echo "  4) Hooks"
            echo "  5) Configure all"
            echo "  6) Done — show summary"
            echo ""

            local menu_choice=""
            read -p "Select option [1-6]: " menu_choice

            case "$menu_choice" in
                1)
                    _git_wizard_identity
                    ;;
                2)
                    _git_wizard_workflow
                    ;;
                3)
                    _git_wizard_aliases
                    ;;
                4)
                    _git_wizard_hooks
                    ;;
                5)
                    _git_wizard_identity
                    _git_wizard_workflow
                    _git_wizard_aliases
                    _git_wizard_hooks
                    ;;
                6)
                    break
                    ;;
                *)
                    echo "Invalid selection. Please choose 1-6." >&2
                    ;;
            esac
        done
    fi

    # Show summary
    _git_wizard_summary

    if ! wizard_yesno "Save this configuration?" "y"; then
        echo ""
        echo "Configuration not saved. Re-run wizard to try again."
        return 0
    fi

    _git_save_config "$ENV_FILE"

    echo ""
    echo "Configuration saved to $ENV_FILE"
    echo ""
    echo "Next steps:"
    echo "  1. Run 'dotconfigs deploy git' to apply settings"
    echo ""
    return 0
}
