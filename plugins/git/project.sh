# plugins/git/project.sh — Git per-project configuration
# Sourced by dotconfigs entry point. Do not execute directly.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Main entry point — called by dotconfigs project command
plugin_git_project() {
    local project_path="$1"

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

    local hooks_dir="$project_path/.git/hooks"
    local hook_file
    local hook_name
    local deployed_count=0

    for hook_file in "$PLUGIN_DIR/hooks/"*; do
        if [[ -f "$hook_file" ]]; then
            hook_name=$(basename "$hook_file")
            local target_hook="$hooks_dir/$hook_name"

            # Check if hook already exists
            if [[ -f "$target_hook" ]]; then
                # Check if it's different (not owned by dotconfigs)
                if ! is_dotconfigs_owned "$target_hook" "$PLUGIN_DIR"; then
                    echo "  Hook '$hook_name' already exists in this repo"
                    if ! wizard_yesno "  Overwrite?" "n"; then
                        echo "  Skipped $hook_name"
                        continue
                    fi
                fi
            fi

            # Copy hook
            cp "$hook_file" "$target_hook"
            chmod +x "$target_hook"
            echo "  ✓ Deployed $hook_name"
            deployed_count=$((deployed_count + 1))
        fi
    done

    if [[ $deployed_count -eq 0 ]]; then
        echo "  No hooks deployed"
    fi

    echo ""

    # Step 2: Per-repo identity (opt-in)
    echo "Step 2: Project-specific git identity"
    echo "──────────────────────────────"

    if wizard_yesno "Configure project-specific git identity?" "n"; then
        local current_name
        local current_email
        local new_name
        local new_email

        # Pre-fill from current repo config if set
        current_name=$(git -C "$project_path" config --local --get user.name 2>/dev/null || echo "")
        current_email=$(git -C "$project_path" config --local --get user.email 2>/dev/null || echo "")

        # Get global as fallback default
        if [[ -z "$current_name" ]]; then
            current_name=$(git config --global --get user.name 2>/dev/null || echo "")
        fi
        if [[ -z "$current_email" ]]; then
            current_email=$(git config --global --get user.email 2>/dev/null || echo "")
        fi

        # Prompt for name and email
        wizard_prompt "  Git user name" "$current_name" new_name
        wizard_prompt "  Git user email" "$current_email" new_email

        # Apply local config
        if [[ -n "$new_name" ]]; then
            git -C "$project_path" config --local user.name "$new_name"
            echo "  ✓ Set local user.name: $new_name"
        fi

        if [[ -n "$new_email" ]]; then
            git -C "$project_path" config --local user.email "$new_email"
            echo "  ✓ Set local user.email: $new_email"
        fi
    else
        echo "  Skipped (global identity will be used)"
    fi

    echo ""

    # Step 3: Per-project configuration note
    echo "Step 3: Per-project hook configuration"
    echo "──────────────────────────────"

    if [[ -f "$project_path/.claude/hooks.conf" ]]; then
        echo "  ℹ Found existing .claude/hooks.conf"
        echo "    Git hook settings can be overridden there"
    else
        echo "  ℹ No .claude/hooks.conf found"
        echo "    To customize conventional commit rules, run:"
        echo "    dotconfigs project claude $project_path"
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Project setup complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
}
