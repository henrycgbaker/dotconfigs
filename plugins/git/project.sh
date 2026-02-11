# plugins/git/project.sh — Git per-project configuration
# Sourced by dotconfigs entry point. Do not execute directly.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ENV_FILE="$DOTCONFIGS_ROOT/.env"

# Load .env if it exists (for GIT_HOOK_CONFIG_PATH)
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

# Main entry point — called by dotconfigs project command
plugin_git_project() {
    local project_path="$1"

    # Initialize colours for G/L badges
    init_colours

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Git Plugin: Project Setup"
    echo "  Project: $(basename "$project_path")"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Validate this is a git repo
    if ! validate_git_repo "$project_path"; then
        return 1
    fi

    # Step 1: Deploy hooks to .git/hooks/
    echo "Step 1: Deploy hooks to .git/hooks/"
    echo "──────────────────────────────"

    # Show globally enabled hooks as reference
    printf "  Global hooks scope: "
    colour_badge_global
    if [[ "${GIT_HOOK_SCOPE:-project}" == "global" ]]; then
        echo " global (core.hooksPath)"
    else
        echo " per-project (default)"
    fi
    echo ""

    echo "  Hooks are copied from dotconfigs into .git/hooks/ (project-local)."
    echo "  They enforce commit messages, secrets detection, branch protection, etc."
    echo "  Each hook reads its config from: ${GIT_HOOK_CONFIG_PATH:-.githooks/config}"
    echo ""

    local hooks_dir="$project_path/.git/hooks"
    local hook_file
    local hook_name
    local deployed_count=0

    for hook_file in "$PLUGIN_DIR/hooks/"*; do
        if [[ -f "$hook_file" ]]; then
            hook_name=$(basename "$hook_file")
            local target_hook="$hooks_dir/$hook_name"

            if backup_and_link "$hook_file" "$target_hook" "$hook_name" "true"; then
                deployed_count=$((deployed_count + 1))
            fi
        fi
    done

    if [[ $deployed_count -eq 0 ]]; then
        echo "  No hooks deployed"
    fi

    echo ""

    # Step 2: Per-repo identity (opt-in)
    echo "Step 2: Project-specific git identity"
    echo "──────────────────────────────"

    # Show global identity as reference
    local global_name=$(git config --global --get user.name 2>/dev/null || echo "not set")
    local global_email=$(git config --global --get user.email 2>/dev/null || echo "not set")
    printf "  Global identity "
    colour_badge_global
    echo ": $global_name <$global_email>"

    # Show local identity if set
    local local_name=$(git -C "$project_path" config --local --get user.name 2>/dev/null || echo "")
    local local_email=$(git -C "$project_path" config --local --get user.email 2>/dev/null || echo "")
    if [[ -n "$local_name" || -n "$local_email" ]]; then
        printf "  Local identity "
        colour_badge_local
        echo ": $local_name <$local_email>"
    fi
    echo ""

    if wizard_yesno "Configure project-specific git identity?" "n"; then
        local current_name="$local_name"
        local current_email="$local_email"
        local new_name
        local new_email

        # Fallback to global if local not set
        if [[ -z "$current_name" ]]; then
            current_name="$global_name"
        fi
        if [[ -z "$current_email" ]]; then
            current_email="$global_email"
        fi

        # Prompt for name and email
        wizard_prompt "  Git user name" "$current_name" new_name
        wizard_prompt "  Git user email" "$current_email" new_email

        # Apply local config
        if [[ -n "$new_name" ]]; then
            git -C "$project_path" config --local user.name "$new_name"
            printf "  ✓ Set local user.name "
            colour_badge_local
            echo ": $new_name"
        fi

        if [[ -n "$new_email" ]]; then
            git -C "$project_path" config --local user.email "$new_email"
            printf "  ✓ Set local user.email "
            colour_badge_local
            echo ": $new_email"
        fi
    else
        echo "  Skipped (global identity will be used)"
    fi

    echo ""

    # Step 3: Deploy hook configuration file
    echo "Step 3: Deploy hook configuration"
    echo "──────────────────────────────"

    # Determine config path (from .env or default)
    local hook_config_path="${GIT_HOOK_CONFIG_PATH:-.githooks/config}"
    local config_target="$project_path/$hook_config_path"
    local config_dir=$(dirname "$config_target")
    local config_template="$PLUGIN_DIR/templates/git-hooks.conf"

    echo "  This is a dotconfigs config file (not a git-native file)."
    echo "  Your hooks read it at runtime for settings like secrets detection,"
    echo "  conventional commits, etc. Location: $hook_config_path"
    echo ""
    if wizard_yesno "Deploy hook configuration to $hook_config_path?" "y"; then
        # Create directory if needed
        mkdir -p "$config_dir"

        # Check if config already exists
        if [[ -f "$config_target" ]]; then
            echo "  Config file already exists"
            if wizard_yesno "  Overwrite?" "n"; then
                cp "$config_template" "$config_target"
                echo "  ✓ Updated $hook_config_path"
            else
                echo "  Skipped (existing config preserved)"
            fi
        else
            cp "$config_template" "$config_target"
            echo "  ✓ Deployed $hook_config_path"
        fi

        # Save config path to .dotconfigs.json
        local dotconfigs_json="$project_path/.dotconfigs.json"
        if command -v jq &> /dev/null; then
            if [[ -f "$dotconfigs_json" ]]; then
                # Update existing
                local temp_json=$(mktemp)
                jq --arg path "$hook_config_path" \
                   '.plugins.git.hook_config_path = $path' \
                   "$dotconfigs_json" > "$temp_json"
                mv "$temp_json" "$dotconfigs_json"
                echo "  ✓ Saved config path to .dotconfigs.json"
            else
                # Create new
                jq -n --arg path "$hook_config_path" \
                   '{version: "2.0", plugins: {git: {hook_config_path: $path}}}' \
                   > "$dotconfigs_json"
                echo "  ✓ Created .dotconfigs.json"
            fi
        else
            echo "  ℹ jq not available - manual .dotconfigs.json update needed"
        fi
    else
        echo "  Skipped hook configuration"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Project setup complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration applied:"

    # Hooks
    if [[ $deployed_count -gt 0 ]]; then
        printf "  "
        colour_badge_local
        echo " Hooks: $deployed_count deployed to .git/hooks/"
    else
        printf "  "
        colour_badge_global
        echo " Hooks: none deployed (using global)"
    fi

    # Identity
    local_name=$(git -C "$project_path" config --local --get user.name 2>/dev/null || echo "")
    local_email=$(git -C "$project_path" config --local --get user.email 2>/dev/null || echo "")
    if [[ -n "$local_name" || -n "$local_email" ]]; then
        printf "  "
        colour_badge_local
        echo " Identity: $local_name <$local_email> (project override)"
    else
        printf "  "
        colour_badge_global
        echo " Identity: using global ($global_name <$global_email>)"
    fi

    echo ""
    echo "Hook roster (7 hooks available):"
    echo "  pre-commit, commit-msg, prepare-commit-msg, pre-push,"
    echo "  post-merge, post-checkout, post-rewrite"
    echo ""
}
