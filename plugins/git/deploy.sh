# plugins/git/deploy.sh — Git configuration deployment
# Sourced by dotconfigs entry point. Do not execute directly.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ENV_FILE="$DOTCONFIGS_ROOT/.env"

# Internal: Load and validate .env configuration
# Returns: 1 if .env doesn't exist, 0 otherwise
_git_load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: No configuration found. Run 'dotconfigs setup git' first." >&2
        return 1
    fi

    # Source .env
    source "$ENV_FILE"

    # Parse GIT_ALIASES_ENABLED space-separated string to array
    if [[ -n "${GIT_ALIASES_ENABLED:-}" ]]; then
        IFS=' ' read -ra GIT_ALIASES_ENABLED_ARRAY <<< "$GIT_ALIASES_ENABLED"
    else
        GIT_ALIASES_ENABLED_ARRAY=()
    fi

    return 0
}

# Internal: Detect configuration drift
# Returns: 0 if drift detected, 1 if no drift
_git_detect_drift() {
    local drift_found=false
    local current_value
    local new_value

    # Check identity settings
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        current_value=$(git config --global --get user.name 2>/dev/null || echo "")
        new_value="$GIT_USER_NAME"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: user.name: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        current_value=$(git config --global --get user.email 2>/dev/null || echo "")
        new_value="$GIT_USER_EMAIL"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: user.email: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    # Check workflow settings
    if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
        current_value=$(git config --global --get pull.rebase 2>/dev/null || echo "")
        new_value="$GIT_PULL_REBASE"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: pull.rebase: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    if [[ -n "${GIT_PUSH_DEFAULT:-}" ]]; then
        current_value=$(git config --global --get push.default 2>/dev/null || echo "")
        new_value="$GIT_PUSH_DEFAULT"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: push.default: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    if [[ -n "${GIT_FETCH_PRUNE:-}" ]]; then
        current_value=$(git config --global --get fetch.prune 2>/dev/null || echo "")
        new_value="$GIT_FETCH_PRUNE"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: fetch.prune: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    if [[ -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]]; then
        current_value=$(git config --global --get init.defaultBranch 2>/dev/null || echo "")
        new_value="$GIT_INIT_DEFAULT_BRANCH"
        if [[ -n "$current_value" && "$current_value" != "$new_value" ]]; then
            echo "  drift: init.defaultBranch: '$current_value' -> '$new_value'"
            drift_found=true
        fi
    fi

    if [[ "$drift_found" == "true" ]]; then
        return 0
    else
        return 1
    fi
}

# Internal: Apply identity settings
_git_deploy_identity() {
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        git config --global user.name "$GIT_USER_NAME"
        echo "  ✓ Set user.name: $GIT_USER_NAME"
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        git config --global user.email "$GIT_USER_EMAIL"
        echo "  ✓ Set user.email: $GIT_USER_EMAIL"
    fi
}

# Internal: Apply workflow settings
_git_deploy_workflow() {
    if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
        git config --global pull.rebase "$GIT_PULL_REBASE"
        echo "  ✓ Set pull.rebase: $GIT_PULL_REBASE"
    fi

    if [[ -n "${GIT_PUSH_DEFAULT:-}" ]]; then
        git config --global push.default "$GIT_PUSH_DEFAULT"
        echo "  ✓ Set push.default: $GIT_PUSH_DEFAULT"
    fi

    if [[ -n "${GIT_FETCH_PRUNE:-}" ]]; then
        git config --global fetch.prune "$GIT_FETCH_PRUNE"
        echo "  ✓ Set fetch.prune: $GIT_FETCH_PRUNE"
    fi

    if [[ -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]]; then
        git config --global init.defaultBranch "$GIT_INIT_DEFAULT_BRANCH"
        echo "  ✓ Set init.defaultBranch: $GIT_INIT_DEFAULT_BRANCH"
    fi

    if [[ "${GIT_RERERE_ENABLED:-}" == "true" ]]; then
        git config --global rerere.enabled true
        echo "  ✓ Set rerere.enabled: true"
    fi

    if [[ -n "${GIT_DIFF_ALGORITHM:-}" ]]; then
        git config --global diff.algorithm "$GIT_DIFF_ALGORITHM"
        echo "  ✓ Set diff.algorithm: $GIT_DIFF_ALGORITHM"
    fi

    if [[ -n "${GIT_HELP_AUTOCORRECT:-}" ]]; then
        git config --global help.autocorrect "$GIT_HELP_AUTOCORRECT"
        echo "  ✓ Set help.autocorrect: $GIT_HELP_AUTOCORRECT"
    fi
}

# Internal: Apply workflow settings with counter tracking
# Args: dry_run, created_counter_var, updated_counter_var, unchanged_counter_var
# Counter vars are passed by name (bash 3.2 compatible, no namerefs)
_git_deploy_workflow_with_tracking() {
    local dry_run="$1"
    local _created_var="$2"
    local _updated_var="$3"
    local _unchanged_var="$4"

    local configs=(
        "pull.rebase:${GIT_PULL_REBASE:-}"
        "push.default:${GIT_PUSH_DEFAULT:-}"
        "fetch.prune:${GIT_FETCH_PRUNE:-}"
        "init.defaultBranch:${GIT_INIT_DEFAULT_BRANCH:-}"
        "diff.algorithm:${GIT_DIFF_ALGORITHM:-}"
        "help.autocorrect:${GIT_HELP_AUTOCORRECT:-}"
    )

    # Add rerere if enabled
    if [[ "${GIT_RERERE_ENABLED:-}" == "true" ]]; then
        configs+=("rerere.enabled:true")
    fi

    for config_spec in "${configs[@]}"; do
        IFS=':' read -r config_key config_value <<< "$config_spec"
        if [[ -z "$config_value" ]]; then
            continue
        fi

        local current_value=$(git config --global --get "$config_key" 2>/dev/null || echo "")

        if [[ "$dry_run" == "true" ]]; then
            if [[ -z "$current_value" ]]; then
                echo "  Would set $config_key: $config_value"
                eval "$_created_var=\$(( \$$_created_var + 1 ))"
            elif [[ "$current_value" != "$config_value" ]]; then
                echo "  Would update $config_key: $current_value -> $config_value"
                eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
            else
                echo "  Unchanged: $config_key"
                eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
            fi
        else
            if [[ -z "$current_value" ]]; then
                git config --global "$config_key" "$config_value"
                echo "  ✓ Set $config_key: $config_value"
                eval "$_created_var=\$(( \$$_created_var + 1 ))"
            elif [[ "$current_value" != "$config_value" ]]; then
                git config --global "$config_key" "$config_value"
                echo "  ✓ Updated $config_key: $config_value"
                eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
            else
                echo "  Unchanged: $config_key"
                eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
            fi
        fi
    done
}

# Internal: Deploy a single alias with drift warning
# Args: alias_name, alias_command
_git_deploy_alias() {
    local alias_name="$1"
    local alias_command="$2"
    local current_alias

    current_alias=$(git config --global --get "alias.$alias_name" 2>/dev/null || echo "")

    if [[ -n "$current_alias" && "$current_alias" != "$alias_command" ]]; then
        echo "  ! Warning: alias '$alias_name' exists with different definition"
        echo "    Current: $current_alias"
        echo "    New:     $alias_command"
    fi

    git config --global "alias.$alias_name" "$alias_command"
    echo "  ✓ Set alias.$alias_name"
}

# Internal: Deploy all enabled aliases
_git_deploy_aliases() {
    local alias_name
    local alias_env_var
    local alias_command
    local default_cmd

    for alias_name in "${GIT_ALIASES_ENABLED_ARRAY[@]}"; do
        # Convert alias name to uppercase for env var lookup
        alias_env_var="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"

        # Try to get definition from env var
        alias_command=$(eval "echo \${${alias_env_var}:-}")

        # If env var is empty, look up default from hardcoded table
        if [[ -z "$alias_command" ]]; then
            case "$alias_name" in
                unstage)
                    default_cmd="reset HEAD --"
                    ;;
                last)
                    default_cmd="log -1 HEAD"
                    ;;
                lg)
                    default_cmd="log --oneline --graph --all --decorate"
                    ;;
                amend)
                    default_cmd="commit --amend --no-edit"
                    ;;
                undo)
                    default_cmd="reset HEAD~1 --mixed"
                    ;;
                wip)
                    default_cmd="commit -am 'WIP'"
                    ;;
                *)
                    echo "  Warning: No definition found for alias '$alias_name', skipping"
                    continue
                    ;;
            esac
            alias_command="$default_cmd"
        fi

        _git_deploy_alias "$alias_name" "$alias_command"
    done
}

# Internal: Deploy all enabled aliases with counter tracking
# Args: dry_run, created_counter_var, updated_counter_var, unchanged_counter_var
# Counter vars are passed by name (bash 3.2 compatible, no namerefs)
_git_deploy_aliases_with_tracking() {
    local dry_run="$1"
    local _created_var="$2"
    local _updated_var="$3"
    local _unchanged_var="$4"

    local alias_name
    local alias_env_var
    local alias_command
    local default_cmd

    for alias_name in "${GIT_ALIASES_ENABLED_ARRAY[@]}"; do
        # Convert alias name to uppercase for env var lookup
        alias_env_var="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"

        # Try to get definition from env var
        alias_command=$(eval "echo \${${alias_env_var}:-}")

        # If env var is empty, look up default from hardcoded table
        if [[ -z "$alias_command" ]]; then
            case "$alias_name" in
                unstage) default_cmd="reset HEAD --" ;;
                last) default_cmd="log -1 HEAD" ;;
                lg) default_cmd="log --oneline --graph --all --decorate" ;;
                amend) default_cmd="commit --amend --no-edit" ;;
                undo) default_cmd="reset HEAD~1 --mixed" ;;
                wip) default_cmd="commit -am 'WIP'" ;;
                *)
                    echo "  Warning: No definition found for alias '$alias_name', skipping"
                    continue
                    ;;
            esac
            alias_command="$default_cmd"
        fi

        local current_alias=$(git config --global --get "alias.$alias_name" 2>/dev/null || echo "")

        if [[ "$dry_run" == "true" ]]; then
            if [[ -z "$current_alias" ]]; then
                echo "  Would set alias.$alias_name"
                eval "$_created_var=\$(( \$$_created_var + 1 ))"
            elif [[ "$current_alias" != "$alias_command" ]]; then
                echo "  Would update alias.$alias_name"
                echo "    Current: $current_alias"
                echo "    New:     $alias_command"
                eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
            else
                echo "  Unchanged: alias.$alias_name"
                eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
            fi
        else
            if [[ -z "$current_alias" ]]; then
                git config --global "alias.$alias_name" "$alias_command"
                echo "  ✓ Set alias.$alias_name"
                eval "$_created_var=\$(( \$$_created_var + 1 ))"
            elif [[ "$current_alias" != "$alias_command" ]]; then
                echo "  ! Warning: alias '$alias_name' exists with different definition"
                echo "    Current: $current_alias"
                echo "    New:     $alias_command"
                git config --global "alias.$alias_name" "$alias_command"
                echo "  ✓ Updated alias.$alias_name"
                eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
            else
                echo "  Unchanged: alias.$alias_name"
                eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
            fi
        fi
    done
}

# Internal: Deploy hooks globally via core.hooksPath
_git_deploy_hooks_global() {
    local target_dir="$HOME/.dotconfigs/git-hooks"
    local hook_file

    # Create target directory
    mkdir -p "$target_dir"

    # Copy all hooks from plugin hooks directory
    for hook_file in "$PLUGIN_DIR/hooks/"*; do
        if [[ -f "$hook_file" ]]; then
            local hook_name=$(basename "$hook_file")
            cp "$hook_file" "$target_dir/$hook_name"
            chmod +x "$target_dir/$hook_name"
            echo "  ✓ Copied $hook_name to global hooks directory"
        fi
    done

    # Set core.hooksPath
    git config --global core.hooksPath "$target_dir"
    echo "  ✓ Set core.hooksPath: $target_dir"
    echo ""
    echo "  ! Warning: Global hooks override per-project hooks in .git/hooks/"
}

# Internal: Deploy hooks globally with counter tracking
# Args: dry_run, created_counter_var, updated_counter_var, unchanged_counter_var
# Counter vars are passed by name (bash 3.2 compatible, no namerefs)
_git_deploy_hooks_global_with_tracking() {
    local dry_run="$1"
    local _created_var="$2"
    local _updated_var="$3"
    local _unchanged_var="$4"

    local target_dir="$HOME/.dotconfigs/git-hooks"
    local hook_file

    if [[ "$dry_run" == "true" ]]; then
        echo "  Would deploy hooks to: $target_dir"

        # Check which hooks would be copied
        for hook_file in "$PLUGIN_DIR/hooks/"*; do
            if [[ -f "$hook_file" ]]; then
                local hook_name=$(basename "$hook_file")
                if [[ -f "$target_dir/$hook_name" ]]; then
                    echo "  Would update: $hook_name"
                    eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
                else
                    echo "  Would copy: $hook_name"
                    eval "$_created_var=\$(( \$$_created_var + 1 ))"
                fi
            fi
        done

        # Check core.hooksPath
        local current_hooks_path=$(git config --global --get core.hooksPath 2>/dev/null || echo "")
        if [[ -z "$current_hooks_path" ]]; then
            echo "  Would set core.hooksPath: $target_dir"
            eval "$_created_var=\$(( \$$_created_var + 1 ))"
        elif [[ "$current_hooks_path" != "$target_dir" ]]; then
            echo "  Would update core.hooksPath: $current_hooks_path -> $target_dir"
            eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
        else
            echo "  Unchanged: core.hooksPath"
            eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
        fi

        echo ""
        echo "  ! Warning: Global hooks override per-project hooks in .git/hooks/"
    else
        # Create target directory
        mkdir -p "$target_dir"

        # Copy all hooks from plugin hooks directory
        for hook_file in "$PLUGIN_DIR/hooks/"*; do
            if [[ -f "$hook_file" ]]; then
                local hook_name=$(basename "$hook_file")
                if [[ -f "$target_dir/$hook_name" ]]; then
                    cp "$hook_file" "$target_dir/$hook_name"
                    chmod +x "$target_dir/$hook_name"
                    echo "  ✓ Updated $hook_name"
                    eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
                else
                    cp "$hook_file" "$target_dir/$hook_name"
                    chmod +x "$target_dir/$hook_name"
                    echo "  ✓ Copied $hook_name to global hooks directory"
                    eval "$_created_var=\$(( \$$_created_var + 1 ))"
                fi
            fi
        done

        # Set core.hooksPath
        local current_hooks_path=$(git config --global --get core.hooksPath 2>/dev/null || echo "")
        if [[ -z "$current_hooks_path" ]]; then
            git config --global core.hooksPath "$target_dir"
            echo "  ✓ Set core.hooksPath: $target_dir"
            eval "$_created_var=\$(( \$$_created_var + 1 ))"
        elif [[ "$current_hooks_path" != "$target_dir" ]]; then
            git config --global core.hooksPath "$target_dir"
            echo "  ✓ Updated core.hooksPath: $target_dir"
            eval "$_updated_var=\$(( \$$_updated_var + 1 ))"
        else
            echo "  Unchanged: core.hooksPath"
            eval "$_unchanged_var=\$(( \$$_unchanged_var + 1 ))"
        fi

        echo ""
        echo "  ! Warning: Global hooks override per-project hooks in .git/hooks/"
    fi
}

# Internal: Print config status in consistent format
# Args: display_name, state, [current_value, expected_value]
_print_config_status() {
    local display_name="$1"
    local state="$2"
    local current_value="${3:-}"
    local expected_value="${4:-}"

    case "$state" in
        deployed)
            printf "  %b %s\n" "$(colour_green "$SYMBOL_OK")" "$display_name"
            ;;
        drifted)
            printf "  %b %s %b\n" "$(colour_yellow "$SYMBOL_DRIFT")" "$display_name" "$(colour_yellow "(current: $current_value, expected: $expected_value)")"
            ;;
        not-deployed)
            printf "  %b %s\n" "$(colour_red "$SYMBOL_MISSING")" "$display_name"
            ;;
        *)
            printf "  ? %s (unknown state: %s)\n" "$display_name" "$state"
            ;;
    esac
}

# Status reporting — called by dotconfigs status command
# Usage: plugin_git_status
plugin_git_status() {
    # Load configuration from .env
    if ! _git_load_config; then
        printf "%b %s\n" "$(colour_red "git")" "not configured"
        return 0
    fi

    # Count states for overall status
    local count_ok=0
    local count_drift=0
    local count_missing=0
    local state current_value expected_value

    # Collect all config items to check
    declare -a config_items=()
    declare -a config_states=()
    declare -a config_names=()
    declare -a config_details=()

    # Check identity settings
    if [[ -n "${GIT_USER_NAME:-}" ]]; then
        current_value=$(git config --global --get user.name 2>/dev/null || echo "")
        expected_value="$GIT_USER_NAME"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("user.name")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
        current_value=$(git config --global --get user.email 2>/dev/null || echo "")
        expected_value="$GIT_USER_EMAIL"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("user.email")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    # Check workflow settings
    if [[ -n "${GIT_PULL_REBASE:-}" ]]; then
        current_value=$(git config --global --get pull.rebase 2>/dev/null || echo "")
        expected_value="$GIT_PULL_REBASE"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("pull.rebase")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    if [[ -n "${GIT_PUSH_DEFAULT:-}" ]]; then
        current_value=$(git config --global --get push.default 2>/dev/null || echo "")
        expected_value="$GIT_PUSH_DEFAULT"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("push.default")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    if [[ -n "${GIT_FETCH_PRUNE:-}" ]]; then
        current_value=$(git config --global --get fetch.prune 2>/dev/null || echo "")
        expected_value="$GIT_FETCH_PRUNE"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("fetch.prune")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    if [[ -n "${GIT_INIT_DEFAULT_BRANCH:-}" ]]; then
        current_value=$(git config --global --get init.defaultBranch 2>/dev/null || echo "")
        expected_value="$GIT_INIT_DEFAULT_BRANCH"
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("init.defaultBranch")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    fi

    # Check aliases
    for alias_name in "${GIT_ALIASES_ENABLED_ARRAY[@]}"; do
        # Get expected value from env or defaults
        alias_env_var="GIT_ALIAS_$(echo "$alias_name" | tr '[:lower:]' '[:upper:]')"
        expected_value=$(eval "echo \${${alias_env_var}:-}")

        if [[ -z "$expected_value" ]]; then
            # Fall back to hardcoded defaults
            case "$alias_name" in
                unstage) expected_value="reset HEAD --" ;;
                last) expected_value="log -1 HEAD" ;;
                lg) expected_value="log --oneline --graph --all --decorate" ;;
                amend) expected_value="commit --amend --no-edit" ;;
                undo) expected_value="reset HEAD~1 --mixed" ;;
                wip) expected_value="commit -am 'WIP'" ;;
                *) continue ;;
            esac
        fi

        current_value=$(git config --global --get "alias.$alias_name" 2>/dev/null || echo "")
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$expected_value" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("alias.$alias_name")
        config_states+=("$state")
        config_details+=("$current_value|$expected_value")
    done

    # Check hooks
    if [[ "${GIT_HOOKS_SCOPE:-project}" == "global" ]]; then
        local hooks_path="$HOME/.dotconfigs/git-hooks"
        current_value=$(git config --global --get core.hooksPath 2>/dev/null || echo "")
        if [[ -z "$current_value" ]]; then
            state="not-deployed"
            ((count_missing++))
        elif [[ "$current_value" != "$hooks_path" ]]; then
            state="drifted"
            ((count_drift++))
        else
            state="deployed"
            ((count_ok++))
        fi
        config_names+=("core.hooksPath (global)")
        config_states+=("$state")
        config_details+=("$current_value|$hooks_path")
    else
        # Project scope: just note it
        config_names+=("hooks (per-project)")
        config_states+=("deployed")
        config_details+=("|")
        ((count_ok++))
    fi

    # Print plugin header with overall status
    if [[ $count_drift -gt 0 ]]; then
        printf "%b %b %s\n" "$(colour_yellow "git")" "$(colour_yellow "$SYMBOL_DRIFT")" "deployed (drift detected)"
    elif [[ $count_missing -gt 0 ]]; then
        printf "%b %b %s\n" "$(colour_yellow "git")" "$(colour_yellow "$SYMBOL_DRIFT")" "partially deployed"
    else
        printf "%b %b %s\n" "$(colour_green "git")" "$(colour_green "$SYMBOL_OK")" "deployed"
    fi

    # Print per-config details
    for i in "${!config_names[@]}"; do
        IFS='|' read -r current expected <<< "${config_details[$i]}"
        _print_config_status "${config_names[$i]}" "${config_states[$i]}" "$current" "$expected"
    done

    return 0
}

# Main entry point — called by dotconfigs CLI
plugin_git_deploy() {
    local dry_run=false
    local force_mode=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dry-run)
                dry_run=true
                shift
                ;;
            --force)
                force_mode=true
                shift
                ;;
            --interactive)
                # Git plugin doesn't use interactive mode for conflicts
                # but accept the flag for consistency
                shift
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                return 1
                ;;
        esac
    done

    # Load configuration from .env
    if ! _git_load_config; then
        return 1
    fi

    # Initialize counters
    local files_created=0
    local files_updated=0
    local files_skipped=0
    local files_unchanged=0

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    if [[ "$dry_run" == "true" ]]; then
        echo "  DRY RUN: Previewing Git configuration deployment"
    else
        echo "  Deploying Git configuration"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Check for drift and confirm (skip in force or dry-run mode)
    if [[ "$force_mode" != "true" && "$dry_run" != "true" ]]; then
        if _git_detect_drift; then
            echo ""
            if ! wizard_yesno "Deploy will overwrite. Continue?" "y"; then
                echo "Deployment cancelled."
                return 1
            fi
            echo ""
        fi
    fi

    # Section 1: Identity
    if [[ -n "${GIT_USER_NAME:-}" || -n "${GIT_USER_EMAIL:-}" ]]; then
        echo "Identity settings:"

        if [[ -n "${GIT_USER_NAME:-}" ]]; then
            local current_name=$(git config --global --get user.name 2>/dev/null || echo "")
            if [[ "$dry_run" == "true" ]]; then
                if [[ -z "$current_name" ]]; then
                    echo "  Would set user.name: $GIT_USER_NAME"
                    ((files_created++))
                elif [[ "$current_name" != "$GIT_USER_NAME" ]]; then
                    echo "  Would update user.name: $current_name -> $GIT_USER_NAME"
                    ((files_updated++))
                else
                    echo "  Unchanged: user.name"
                    ((files_unchanged++))
                fi
            else
                if [[ -z "$current_name" ]]; then
                    git config --global user.name "$GIT_USER_NAME"
                    echo "  ✓ Set user.name: $GIT_USER_NAME"
                    ((files_created++))
                elif [[ "$current_name" != "$GIT_USER_NAME" ]]; then
                    git config --global user.name "$GIT_USER_NAME"
                    echo "  ✓ Updated user.name: $GIT_USER_NAME"
                    ((files_updated++))
                else
                    echo "  Unchanged: user.name"
                    ((files_unchanged++))
                fi
            fi
        fi

        if [[ -n "${GIT_USER_EMAIL:-}" ]]; then
            local current_email=$(git config --global --get user.email 2>/dev/null || echo "")
            if [[ "$dry_run" == "true" ]]; then
                if [[ -z "$current_email" ]]; then
                    echo "  Would set user.email: $GIT_USER_EMAIL"
                    ((files_created++))
                elif [[ "$current_email" != "$GIT_USER_EMAIL" ]]; then
                    echo "  Would update user.email: $current_email -> $GIT_USER_EMAIL"
                    ((files_updated++))
                else
                    echo "  Unchanged: user.email"
                    ((files_unchanged++))
                fi
            else
                if [[ -z "$current_email" ]]; then
                    git config --global user.email "$GIT_USER_EMAIL"
                    echo "  ✓ Set user.email: $GIT_USER_EMAIL"
                    ((files_created++))
                elif [[ "$current_email" != "$GIT_USER_EMAIL" ]]; then
                    git config --global user.email "$GIT_USER_EMAIL"
                    echo "  ✓ Updated user.email: $GIT_USER_EMAIL"
                    ((files_updated++))
                else
                    echo "  Unchanged: user.email"
                    ((files_unchanged++))
                fi
            fi
        fi

        echo ""
    fi

    # Section 2: Workflow settings
    echo "Workflow settings:"
    _git_deploy_workflow_with_tracking "$dry_run" files_created files_updated files_unchanged
    echo ""

    # Section 3: Aliases
    if [[ ${#GIT_ALIASES_ENABLED_ARRAY[@]} -gt 0 ]]; then
        echo "Aliases:"
        _git_deploy_aliases_with_tracking "$dry_run" files_created files_updated files_unchanged
        echo ""
    fi

    # Section 4: Hooks
    echo "Hooks:"
    if [[ "${GIT_HOOKS_SCOPE:-project}" == "global" ]]; then
        _git_deploy_hooks_global_with_tracking "$dry_run" files_created files_updated files_unchanged
        echo ""
        echo "  Hook roster (7 hooks deployed):"
        echo "    pre-commit         - secrets, large files, debug checks"
        echo "    commit-msg         - AI attribution, WIP, conventional format"
        echo "    prepare-commit-msg - branch name prefix"
        echo "    pre-push           - branch protection"
        echo "    post-merge         - dependency changes, migrations"
        echo "    post-checkout      - branch info"
        echo "    post-rewrite       - dependency changes (rebase)"
    else
        echo "  Hooks configured for per-project deployment."
        echo "  Run 'dotconfigs project git <path>' to deploy hooks to a specific repo."
        echo ""
        echo "  Hook roster (7 hooks available):"
        echo "    pre-commit, commit-msg, prepare-commit-msg, pre-push,"
        echo "    post-merge, post-checkout, post-rewrite"
    fi
    echo ""

    echo "═══════════════════════════════════════════════════════════"
    if [[ "$dry_run" == "true" ]]; then
        echo "  Dry run complete!"
    else
        echo "  Deployment complete!"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Deploy summary:"
    echo "  Created:   $files_created"
    echo "  Updated:   $files_updated"
    echo "  Skipped:   $files_skipped"
    echo "  Unchanged: $files_unchanged"
    echo ""

    if [[ "$dry_run" == "true" ]]; then
        echo "Dry run complete. Run without --dry-run to apply changes."
        echo ""
    fi

    return 0
}
