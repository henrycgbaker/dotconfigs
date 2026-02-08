# plugins/git/setup.sh — Git configuration setup wizard
# Sourced by dotconfigs entry point. Do not execute directly.

# Internal: Identity section wizard
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

# Internal: Workflow settings section wizard
_git_wizard_workflow() {
    wizard_header 2 "Workflow Settings"
    echo "Configure git workflow preferences"
    echo ""

    echo "Core settings (recommended defaults):"
    echo ""

    # Core settings (enabled by default, user opts out)
    local pull_rebase_default="y"
    [[ "${GIT_PULL_REBASE:-true}" == "false" ]] && pull_rebase_default="n"
    if wizard_yesno "  pull.rebase = true (rebase instead of merge on pull)" "$pull_rebase_default"; then
        GIT_PULL_REBASE="true"
    else
        GIT_PULL_REBASE="false"
    fi

    local push_default_default="y"
    [[ "${GIT_PUSH_DEFAULT:-simple}" != "simple" ]] && push_default_default="n"
    if wizard_yesno "  push.default = simple (push current branch only)" "$push_default_default"; then
        GIT_PUSH_DEFAULT="simple"
    else
        GIT_PUSH_DEFAULT="current"
    fi

    local fetch_prune_default="y"
    [[ "${GIT_FETCH_PRUNE:-true}" == "false" ]] && fetch_prune_default="n"
    if wizard_yesno "  fetch.prune = true (auto-delete removed remote branches)" "$fetch_prune_default"; then
        GIT_FETCH_PRUNE="true"
    else
        GIT_FETCH_PRUNE="false"
    fi

    local default_branch="${GIT_INIT_DEFAULT_BRANCH:-main}"
    wizard_prompt "  init.defaultBranch (default branch name for new repos)" "$default_branch" GIT_INIT_DEFAULT_BRANCH

    echo ""
    echo "Advanced settings (opt-in):"
    echo ""

    # Advanced settings (opt-in, disabled by default)
    local rerere_default="n"
    [[ "${GIT_RERERE_ENABLED:-false}" == "true" ]] && rerere_default="y"
    if wizard_yesno "  rerere.enabled = true (reuse recorded conflict resolutions)" "$rerere_default"; then
        GIT_RERERE_ENABLED="true"
    else
        GIT_RERERE_ENABLED="false"
    fi

    local diff_algo_default="n"
    [[ -n "${GIT_DIFF_ALGORITHM:-}" ]] && diff_algo_default="y"
    if wizard_yesno "  diff.algorithm = histogram (better diff output)" "$diff_algo_default"; then
        GIT_DIFF_ALGORITHM="histogram"
    else
        GIT_DIFF_ALGORITHM=""
    fi

    local autocorrect_default="n"
    [[ -n "${GIT_HELP_AUTOCORRECT:-}" ]] && autocorrect_default="y"
    if wizard_yesno "  help.autocorrect = 10 (auto-run typo corrections after 1s)" "$autocorrect_default"; then
        GIT_HELP_AUTOCORRECT="10"
    else
        GIT_HELP_AUTOCORRECT=""
    fi
}

# Internal: Aliases section wizard
_git_wizard_aliases() {
    wizard_header 3 "Aliases"
    echo "Configure git command aliases"
    echo ""

    # Default aliases with definitions
    local default_alias_unstage="reset HEAD --"
    local default_alias_last="log -1 HEAD"
    local default_alias_lg="log --oneline --graph --all --decorate"
    local default_alias_amend="commit --amend --no-edit"
    local default_alias_undo="reset HEAD~1 --mixed"
    local default_alias_wip="commit -am \"WIP\""

    # Pre-fill enabled list from .env
    local enabled_list="${GIT_ALIASES_ENABLED:-unstage last lg amend undo wip}"
    local alias_names=(unstage last lg amend undo wip)
    local enabled_names=""

    echo "Default aliases (enable/disable each):"
    echo ""

    for alias_name in "${alias_names[@]}"; do
        local alias_var="default_alias_${alias_name}"
        local alias_cmd="${!alias_var}"
        local alias_default="y"

        # Check if this alias was previously disabled
        if ! _is_in_list "$alias_name" "$enabled_list"; then
            alias_default="n"
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

# Internal: Hooks section wizard
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

    # Pre-push protection level
    echo "Pre-push protection level:"
    echo "  1) warn  - show warning but allow push"
    echo "  2) block - prevent accidental force-push to main/master"
    echo "  3) off   - no pre-push checks"
    echo ""
    local protection_default="${GIT_HOOK_PREPUSH_PROTECTION:-warn}"
    local protection_index=1
    case "$protection_default" in
        warn) protection_index=1 ;;
        block) protection_index=2 ;;
        off) protection_index=3 ;;
    esac

    PS3="Select protection level [$protection_default]: "
    select protection_level in "warn" "block" "off"; do
        if [[ -n "$protection_level" ]]; then
            GIT_HOOK_PREPUSH_PROTECTION="$protection_level"
            break
        fi
    done

    # Conventional commits
    echo ""
    local conventional_default="y"
    [[ "${GIT_HOOK_CONVENTIONAL_COMMITS:-true}" == "false" ]] && conventional_default="n"
    if wizard_yesno "Enforce conventional commit messages?" "$conventional_default"; then
        GIT_HOOK_CONVENTIONAL_COMMITS="true"
    else
        GIT_HOOK_CONVENTIONAL_COMMITS="false"
    fi
}

# Internal: Save all GIT_* config to .env
_git_save_config() {
    local env_file="$1"

    # Ensure .env exists with header
    if [[ ! -f "$env_file" ]]; then
        cat > "$env_file" <<'EOF'
# dotconfigs configuration
# Generated by: dotconfigs setup git (wizard)
# Re-run wizard: dotconfigs setup git

EOF
    fi

    # Save identity
    wizard_save_env "$env_file" "GIT_USER_NAME" "$GIT_USER_NAME"
    wizard_save_env "$env_file" "GIT_USER_EMAIL" "$GIT_USER_EMAIL"

    # Save workflow settings
    wizard_save_env "$env_file" "GIT_PULL_REBASE" "$GIT_PULL_REBASE"
    wizard_save_env "$env_file" "GIT_PUSH_DEFAULT" "$GIT_PUSH_DEFAULT"
    wizard_save_env "$env_file" "GIT_FETCH_PRUNE" "$GIT_FETCH_PRUNE"
    wizard_save_env "$env_file" "GIT_INIT_DEFAULT_BRANCH" "$GIT_INIT_DEFAULT_BRANCH"
    wizard_save_env "$env_file" "GIT_RERERE_ENABLED" "$GIT_RERERE_ENABLED"
    [[ -n "$GIT_DIFF_ALGORITHM" ]] && wizard_save_env "$env_file" "GIT_DIFF_ALGORITHM" "$GIT_DIFF_ALGORITHM"
    [[ -n "$GIT_HELP_AUTOCORRECT" ]] && wizard_save_env "$env_file" "GIT_HELP_AUTOCORRECT" "$GIT_HELP_AUTOCORRECT"

    # Save aliases enabled list
    wizard_save_env "$env_file" "GIT_ALIASES_ENABLED" "$GIT_ALIASES_ENABLED"

    # Save individual alias definitions
    for alias_name in $GIT_ALIASES_ENABLED; do
        local alias_key="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"
        local alias_value="${!alias_key}"
        [[ -n "$alias_value" ]] && wizard_save_env "$env_file" "$alias_key" "$alias_value"
    done

    # Save hooks settings
    wizard_save_env "$env_file" "GIT_HOOKS_SCOPE" "$GIT_HOOKS_SCOPE"
    wizard_save_env "$env_file" "GIT_HOOK_PREPUSH_PROTECTION" "$GIT_HOOK_PREPUSH_PROTECTION"
    wizard_save_env "$env_file" "GIT_HOOK_CONVENTIONAL_COMMITS" "$GIT_HOOK_CONVENTIONAL_COMMITS"
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

    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║               dotconfigs — Git Configuration               ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""

    # Menu loop
    while true; do
        echo ""
        echo "═══════════════════════════════════════════════════════════"
        echo "  Configuration Menu"
        echo "═══════════════════════════════════════════════════════════"
        echo ""

        # Show section status
        local identity_status="✗ not configured"
        [[ -n "${GIT_USER_NAME:-}" ]] && identity_status="✓ configured"

        local workflow_status="✗ not configured"
        [[ -n "${GIT_PULL_REBASE:-}" ]] && workflow_status="✓ configured"

        local aliases_status="✗ not configured"
        [[ -n "${GIT_ALIASES_ENABLED:-}" ]] && aliases_status="✓ configured"

        local hooks_status="✗ not configured"
        [[ -n "${GIT_HOOKS_SCOPE:-}" ]] && hooks_status="✓ configured"

        echo "  1) Configure Identity          $identity_status"
        echo "  2) Configure Workflow Settings $workflow_status"
        echo "  3) Configure Aliases           $aliases_status"
        echo "  4) Configure Hooks             $hooks_status"
        echo "  5) Configure All"
        echo "  6) Done -- save and exit"
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
                # Summary and save
                echo ""
                echo "═══════════════════════════════════════════════════════════"
                echo "  Configuration Summary"
                echo "═══════════════════════════════════════════════════════════"
                echo ""
                echo "Identity:"
                echo "  user.name:  ${GIT_USER_NAME:-<not set>}"
                echo "  user.email: ${GIT_USER_EMAIL:-<not set>}"
                echo ""
                echo "Workflow:"
                echo "  pull.rebase:         ${GIT_PULL_REBASE:-<not set>}"
                echo "  push.default:        ${GIT_PUSH_DEFAULT:-<not set>}"
                echo "  fetch.prune:         ${GIT_FETCH_PRUNE:-<not set>}"
                echo "  init.defaultBranch:  ${GIT_INIT_DEFAULT_BRANCH:-<not set>}"
                echo "  rerere.enabled:      ${GIT_RERERE_ENABLED:-false}"
                echo "  diff.algorithm:      ${GIT_DIFF_ALGORITHM:-<not set>}"
                echo "  help.autocorrect:    ${GIT_HELP_AUTOCORRECT:-<not set>}"
                echo ""
                echo "Aliases:"
                echo "  Enabled: ${GIT_ALIASES_ENABLED:-<none>}"
                echo ""
                echo "Hooks:"
                echo "  Scope:               ${GIT_HOOKS_SCOPE:-<not set>}"
                echo "  Pre-push protection: ${GIT_HOOK_PREPUSH_PROTECTION:-<not set>}"
                echo "  Conventional commits: ${GIT_HOOK_CONVENTIONAL_COMMITS:-<not set>}"
                echo ""

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
                ;;
            *)
                echo "Invalid selection. Please choose 1-6." >&2
                ;;
        esac
    done
}
