# plugins/claude/project.sh — Claude Code project scaffolding
# Sourced by dotconfigs entry point. Do not execute directly.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ENV_FILE="$DOTCONFIGS_ROOT/.env"

# Load .env if it exists (for global config references)
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
fi

# Internal: Detect project type from filesystem
_claude_detect_project_type() {
    local project_path="$1"

    # Check for Python
    if [[ -f "$project_path/pyproject.toml" ]] || \
       [[ -f "$project_path/setup.py" ]] || \
       [[ -f "$project_path/requirements.txt" ]] || \
       find "$project_path" -maxdepth 1 -name "*.py" -type f 2>/dev/null | grep -q .; then
        echo "python"
        return
    fi

    # Check for Node
    if [[ -f "$project_path/package.json" ]]; then
        echo "node"
        return
    fi

    # Check for Go
    if [[ -f "$project_path/go.mod" ]]; then
        echo "go"
        return
    fi

    # Default
    echo "generic"
}

# Internal: Merge JSON settings files
_claude_merge_settings_json() {
    local base_file="$1"
    local overlay_file="$2"
    local output_file="$3"

    # Use jq to merge if available, otherwise simple concat approach
    if command -v jq &> /dev/null; then
        jq -s '.[0] * .[1]' "$base_file" "$overlay_file" > "$output_file"
    else
        # Fallback: Python-based merge
        python3 <<EOF
import json
import sys

try:
    with open("$base_file") as f:
        base = json.load(f)
    with open("$overlay_file") as f:
        overlay = json.load(f)

    # Deep merge
    def deep_merge(base, overlay):
        for key, value in overlay.items():
            if key in base and isinstance(base[key], dict) and isinstance(value, dict):
                deep_merge(base[key], value)
            elif key in base and isinstance(base[key], list) and isinstance(value, list):
                base[key].extend(value)
            else:
                base[key] = value
        return base

    result = deep_merge(base, overlay)

    with open("$output_file", "w") as f:
        json.dump(result, f, indent=2)
except Exception as e:
    print(f"Error merging JSON: {e}", file=sys.stderr)
    sys.exit(1)
EOF
    fi
}

# Internal: Write project config to .dotconfigs.json
_claude_write_project_config() {
    local project_path="$1"
    local project_type="$2"
    local settings_profile="$3"
    local pretooluse_enabled="$4"
    local config_file="$project_path/.dotconfigs.json"

    if command -v jq &> /dev/null; then
        # Use jq to create/update config
        local temp_config=$(mktemp)

        if [[ -f "$config_file" ]]; then
            # Update existing config
            jq --arg ptype "$project_type" \
               --arg sprof "$settings_profile" \
               --argjson ptool "$pretooluse_enabled" \
               '.plugins.claude = {
                   "project_type": $ptype,
                   "settings_profile": $sprof,
                   "pretooluse_enabled": $ptool
               }' "$config_file" > "$temp_config"
        else
            # Create new config
            jq -n --arg ptype "$project_type" \
                  --arg sprof "$settings_profile" \
                  --argjson ptool "$pretooluse_enabled" \
                  '{
                      "version": "2.0",
                      "plugins": {
                          "claude": {
                              "project_type": $ptype,
                              "settings_profile": $sprof,
                              "pretooluse_enabled": $ptool
                          }
                      }
                  }' > "$temp_config"
        fi

        mv "$temp_config" "$config_file"
    else
        # Fallback: printf-based JSON creation (simple structure)
        if [[ -f "$config_file" ]]; then
            echo "Warning: jq not available, cannot merge existing .dotconfigs.json" >&2
            echo "Manual merge required" >&2
            return 1
        fi

        cat > "$config_file" <<EOF
{
  "version": "2.0",
  "plugins": {
    "claude": {
      "project_type": "$project_type",
      "settings_profile": "$settings_profile",
      "pretooluse_enabled": $pretooluse_enabled
    }
  }
}
EOF
    fi
}

# Main entry point — called by dotconfigs project command
plugin_claude_project() {
    local project_path="$1"

    # Initialize colours for G/L badges
    init_colours

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Claude Plugin: Project Scaffolding"
    echo "  Project: $(basename "$project_path")"
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Detect project state (greenfield vs brownfield)
    local is_greenfield=true
    local existing_claude_dir=false
    local existing_claude_md=false

    if [[ -d "$project_path/.claude" ]]; then
        existing_claude_dir=true
        is_greenfield=false
        echo "  ℹ Existing .claude/ directory detected (brownfield)"
    fi

    if [[ -f "$project_path/CLAUDE.md" ]]; then
        existing_claude_md=true
        is_greenfield=false
        echo "  ℹ Existing CLAUDE.md detected"
    fi

    if [[ "$is_greenfield" == "true" ]]; then
        echo "  ✓ Greenfield project (no existing configuration)"
    fi

    echo ""

    # Detect project type
    local project_type=$(_claude_detect_project_type "$project_path")
    echo "Project type: $project_type"
    echo ""

    # Step 1: Build and deploy settings.json
    echo "Step 1: Project settings.json"
    echo "──────────────────────────────"

    # Show global settings as reference
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        printf "  Global settings "
        colour_badge_global
        echo ": enabled"
        [[ "${CLAUDE_SETTINGS_PYTHON:-false}" == "true" ]] && printf "    - Python rules "
        [[ "${CLAUDE_SETTINGS_PYTHON:-false}" == "true" ]] && colour_badge_global && echo ""
        [[ "${CLAUDE_SETTINGS_NODE:-false}" == "true" ]] && printf "    - Node rules "
        [[ "${CLAUDE_SETTINGS_NODE:-false}" == "true" ]] && colour_badge_global && echo ""
    else
        printf "  Global settings "
        colour_badge_global
        echo ": disabled"
    fi
    echo ""

    local claude_dir="$project_path/.claude"
    mkdir -p "$claude_dir"

    local settings_target="$claude_dir/settings.json"
    local base_settings="$PLUGIN_DIR/templates/settings/base.json"
    local type_settings="$PLUGIN_DIR/templates/settings/${project_type}.json"
    local settings_profile="base"
    local is_local_override=false

    if [[ -f "$settings_target" ]]; then
        echo "  Existing settings.json found"
        if wizard_yesno "  Overwrite settings.json?" "n"; then
            # Continue to build
            settings_profile="base+${project_type}"
            is_local_override=true
        else
            echo "  Skipped settings.json"
            settings_target=""
        fi
    else
        if wizard_yesno "  Create project-specific settings.json?" "y"; then
            is_local_override=true
        else
            echo "  Skipped (will use global settings)"
            settings_target=""
        fi
    fi

    if [[ -n "$settings_target" ]]; then
        if [[ -f "$type_settings" ]]; then
            # Merge base + type overlay
            _claude_merge_settings_json "$base_settings" "$type_settings" "$settings_target"
            printf "  ✓ Built settings.json "
            colour_badge_local
            echo " from base + $project_type overlay"
            settings_profile="base+${project_type}"
        else
            # Copy base only
            cp "$base_settings" "$settings_target"
            printf "  ✓ Copied base settings.json "
            colour_badge_local
            echo ""
            settings_profile="base"
        fi
    fi

    echo ""

    # Step 2: Deploy Claude hooks
    echo "Step 2: Deploy Claude hooks"
    echo "──────────────────────────────"

    # Show globally enabled hooks as reference
    if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
        printf "  Global hooks "
        colour_badge_global
        echo ": $CLAUDE_HOOKS_ENABLED"
    else
        printf "  Global hooks "
        colour_badge_global
        echo ": none"
    fi
    echo ""

    # Ask about PreToolUse hook
    local enable_pretooluse="true"
    if wizard_yesno "Enable PreToolUse hook (blocks destructive commands)?" "y"; then
        enable_pretooluse="true"

        # Deploy block-destructive.sh to .claude/hooks/
        local hooks_dir="$claude_dir/hooks"
        mkdir -p "$hooks_dir"

        local hook_source="$PLUGIN_DIR/hooks/block-destructive.sh"
        local hook_target="$hooks_dir/block-destructive.sh"

        cp "$hook_source" "$hook_target"
        chmod +x "$hook_target"
        printf "  ✓ Deployed block-destructive.sh "
        colour_badge_local
        echo " to .claude/hooks/"

        # Merge hooks.json template into settings.json
        local hooks_json_template="$PLUGIN_DIR/templates/settings/hooks.json"
        if [[ -f "$settings_target" && -f "$hooks_json_template" ]]; then
            if command -v jq &> /dev/null; then
                # Deep merge hooks section
                local temp_settings=$(mktemp)
                jq -s '.[0] * .[1]' "$settings_target" "$hooks_json_template" > "$temp_settings"
                mv "$temp_settings" "$settings_target"
                echo "  ✓ Merged hooks configuration into settings.json"
            else
                echo "  ⚠ jq not available - manual hooks.json merge needed"
            fi
        fi
    else
        enable_pretooluse="false"
        echo "  Skipped PreToolUse hook"
    fi

    # Deploy claude-hooks.conf configuration
    local hooks_conf_target="$claude_dir/claude-hooks.conf"
    local hooks_conf_template="$PLUGIN_DIR/templates/claude-hooks.conf"

    if wizard_yesno "Deploy Claude hook configuration file?" "y"; then
        if [[ -f "$hooks_conf_target" ]]; then
            echo "  Existing claude-hooks.conf found"
            if wizard_yesno "  Overwrite?" "n"; then
                cp "$hooks_conf_template" "$hooks_conf_target"
                echo "  ✓ Updated claude-hooks.conf"
            else
                echo "  Skipped (existing config preserved)"
            fi
        else
            cp "$hooks_conf_template" "$hooks_conf_target"
            echo "  ✓ Deployed claude-hooks.conf"

            # Adjust Ruff default based on project type
            if [[ "$project_type" != "python" ]]; then
                # Disable Ruff for non-Python projects
                if [[ "$OSTYPE" == "darwin"* ]]; then
                    sed -i '' 's/^CLAUDE_HOOK_RUFF_FORMAT=true/CLAUDE_HOOK_RUFF_FORMAT=false/' "$hooks_conf_target"
                else
                    sed -i 's/^CLAUDE_HOOK_RUFF_FORMAT=true/CLAUDE_HOOK_RUFF_FORMAT=false/' "$hooks_conf_target"
                fi
                echo "  ✓ Disabled Ruff for non-Python project"
            fi
        fi
    else
        echo "  Skipped hook configuration"
    fi

    echo ""

    # Step 3: Create/update CLAUDE.md
    echo "Step 3: Project CLAUDE.md"
    echo "──────────────────────────────"

    # Show global CLAUDE.md sections as reference
    if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
        printf "  Global CLAUDE.md "
        colour_badge_global
        echo ": $CLAUDE_MD_SECTIONS"
    else
        printf "  Global CLAUDE.md "
        colour_badge_global
        echo ": none"
    fi
    echo ""

    local claude_md_target="$project_path/CLAUDE.md"

    if [[ -f "$claude_md_target" ]]; then
        echo "  Existing CLAUDE.md found. Choose action:"
        echo "    1) Append dotconfigs section"
        echo "    2) Skip"
        echo ""
        read -p "  Select [1-2]: " action
        case "$action" in
            1)
                cat >> "$claude_md_target" <<EOF

## Project Configuration

Project type: $project_type
Configuration managed by: dotconfigs

For global Claude instructions, see: ~/.claude/CLAUDE.md
EOF
                printf "  ✓ Appended dotconfigs section "
                colour_badge_local
                echo " to CLAUDE.md"
                ;;
            2|*)
                echo "  Skipped CLAUDE.md"
                ;;
        esac
    else
        if wizard_yesno "  Create project CLAUDE.md from global sections?" "y"; then
            # Source deploy.sh to get _claude_build_md if not already loaded
            if ! declare -f _claude_build_md > /dev/null 2>&1; then
                source "$PLUGIN_DIR/deploy.sh"
            fi

            # Load config to get CLAUDE_MD_SECTIONS
            if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
                IFS=' ' read -ra _sections <<< "$CLAUDE_MD_SECTIONS"
            else
                _sections=()
            fi

            if [[ ${#_sections[@]} -gt 0 ]]; then
                # Build assembled CLAUDE.md in plugin dir, then copy to project
                _claude_build_md "$PLUGIN_DIR" "${_sections[@]}"
                cp "$PLUGIN_DIR/CLAUDE.md" "$claude_md_target"
                printf "  ✓ Built CLAUDE.md from global sections "
                colour_badge_local
                echo " (${#_sections[@]} sections)"
            else
                # No sections configured — create minimal stub
                cat > "$claude_md_target" <<MDEOF
# $(basename "$project_path")

Project type: $project_type
MDEOF
                printf "  ✓ Created minimal CLAUDE.md "
                colour_badge_local
                echo " (no global sections configured)"
            fi
        else
            echo "  Skipped CLAUDE.md"
        fi
    fi

    echo ""

    # Step 3.5: CLAUDE.md exclusion (per-project override)
    echo "Step 3.5: CLAUDE.md exclusion"
    echo "──────────────────────────────"

    # Show global exclusion setting
    if [[ "${CLAUDE_MD_EXCLUDE_GLOBAL:-false}" == "true" ]]; then
        printf "  Global exclusion "
        colour_badge_global
        echo ": enabled (${CLAUDE_MD_EXCLUDE_PATTERN:-CLAUDE.md})"
    else
        printf "  Global exclusion "
        colour_badge_global
        echo ": disabled"
    fi
    echo ""

    if wizard_yesno "  Apply CLAUDE.md exclusion for this project?" "y"; then
        local git_exclude="$project_path/.git/info/exclude"
        local pattern="${CLAUDE_MD_EXCLUDE_PATTERN:-CLAUDE.md}"

        # Create exclude file if needed
        if [[ ! -f "$git_exclude" ]]; then
            mkdir -p "$(dirname "$git_exclude")"
            touch "$git_exclude"
        fi

        # Add pattern if not present
        if ! grep -q "^${pattern}$" "$git_exclude" 2>/dev/null; then
            echo "$pattern" >> "$git_exclude"
            printf "  ✓ Added $pattern "
            colour_badge_local
            echo " to .git/info/exclude"
        else
            echo "  Already excluded: $pattern"
        fi
    else
        echo "  Skipped CLAUDE.md exclusion"
    fi

    echo ""

    # Step 4: Update .git/info/exclude
    echo "Step 4: Git exclusions"
    echo "──────────────────────────────"

    local git_exclude="$project_path/.git/info/exclude"

    # Ensure file exists
    touch "$git_exclude"

    # Add entries if not present
    local added_count=0

    if ! grep -q "^CLAUDE.md$" "$git_exclude" 2>/dev/null; then
        echo "CLAUDE.md" >> "$git_exclude"
        added_count=$((added_count + 1))
    fi

    if ! grep -q "^\.claude/$" "$git_exclude" 2>/dev/null; then
        echo ".claude/" >> "$git_exclude"
        added_count=$((added_count + 1))
    fi

    if ! grep -q "^\.dotconfigs\.json$" "$git_exclude" 2>/dev/null; then
        echo ".dotconfigs.json" >> "$git_exclude"
        added_count=$((added_count + 1))
    fi

    if [[ $added_count -gt 0 ]]; then
        echo "  ✓ Added $added_count exclusion(s) to .git/info/exclude"
    else
        echo "  ✓ All exclusions already present"
    fi

    echo ""

    # Step 5: Save to .dotconfigs.json
    echo "Step 5: Save project configuration"
    echo "──────────────────────────────"

    _claude_write_project_config "$project_path" "$project_type" "$settings_profile" "$enable_pretooluse"

    if [[ $? -eq 0 ]]; then
        echo "  ✓ Saved configuration to .dotconfigs.json"
    else
        echo "  ✗ Failed to save configuration" >&2
    fi

    echo ""

    # Step 6: Ask commit or exclude .dotconfigs.json
    echo "Step 6: Version control for .dotconfigs.json"
    echo "──────────────────────────────"

    if wizard_yesno "  Commit .dotconfigs.json to git?" "n"; then
        echo "  ✓ .dotconfigs.json will be tracked in git"
        echo "    (Commit it manually with: git add .dotconfigs.json)"
    else
        # Add to .git/info/exclude
        if ! grep -q "^\.dotconfigs\.json$" "$git_exclude" 2>/dev/null; then
            echo ".dotconfigs.json" >> "$git_exclude"
            echo "  ✓ Added .dotconfigs.json to .git/info/exclude"
        else
            echo "  ✓ .dotconfigs.json already in .git/info/exclude"
        fi
    fi

    echo ""
    echo "═══════════════════════════════════════════════════════════"
    echo "  Project scaffolding complete!"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration applied:"

    # Settings.json
    if [[ "$is_local_override" == "true" ]]; then
        printf "  "
        colour_badge_local
        echo " Settings.json: $settings_profile (project override)"
    else
        printf "  "
        colour_badge_global
        echo " Settings.json: using global (no override)"
    fi

    # Hooks
    if [[ "$enable_pretooluse" == "true" ]]; then
        printf "  "
        colour_badge_local
        echo " Hooks: block-destructive.sh (project)"
    else
        printf "  "
        colour_badge_global
        echo " Hooks: none (using global)"
    fi

    # CLAUDE.md
    if [[ -f "$claude_md_target" ]]; then
        printf "  "
        colour_badge_local
        echo " CLAUDE.md: project-specific"
    else
        printf "  "
        colour_badge_global
        echo " CLAUDE.md: using global"
    fi

    echo ""
    echo "Files created/updated:"
    echo "  - .claude/settings.json"
    [[ "$enable_pretooluse" == "true" ]] && echo "  - .claude/hooks/block-destructive.sh"
    echo "  - .claude/claude-hooks.conf"
    [[ -f "$claude_md_target" ]] && echo "  - CLAUDE.md"
    echo "  - .git/info/exclude"
    echo "  - .dotconfigs.json"
    echo ""
}
