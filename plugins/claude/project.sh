# plugins/claude/project.sh — Claude Code project scaffolding
# Sourced by dotconfigs entry point. Do not execute directly.

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    local hooks_profile="$4"
    local config_file="$project_path/.dotconfigs.json"

    if command -v jq &> /dev/null; then
        # Use jq to create/update config
        local temp_config=$(mktemp)

        if [[ -f "$config_file" ]]; then
            # Update existing config
            jq --arg ptype "$project_type" \
               --arg sprof "$settings_profile" \
               --arg hprof "$hooks_profile" \
               '.plugins.claude = {
                   "project_type": $ptype,
                   "settings_profile": $sprof,
                   "hooks_profile": $hprof
               }' "$config_file" > "$temp_config"
        else
            # Create new config
            jq -n --arg ptype "$project_type" \
                  --arg sprof "$settings_profile" \
                  --arg hprof "$hooks_profile" \
                  '{
                      "version": "2.0",
                      "plugins": {
                          "claude": {
                              "project_type": $ptype,
                              "settings_profile": $sprof,
                              "hooks_profile": $hprof
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
      "hooks_profile": "$hooks_profile"
    }
  }
}
EOF
    fi
}

# Main entry point — called by dotconfigs project command
plugin_claude_project() {
    local project_path="$1"

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

    local claude_dir="$project_path/.claude"
    mkdir -p "$claude_dir"

    local settings_target="$claude_dir/settings.json"
    local base_settings="$PLUGIN_DIR/templates/settings/base.json"
    local type_settings="$PLUGIN_DIR/templates/settings/${project_type}.json"
    local settings_profile="base"

    if [[ -f "$settings_target" ]]; then
        echo "  Existing settings.json found"
        if wizard_yesno "  Overwrite settings.json?" "n"; then
            # Continue to build
            settings_profile="base+${project_type}"
        else
            echo "  Skipped settings.json"
            settings_target=""
        fi
    fi

    if [[ -n "$settings_target" ]]; then
        if [[ -f "$type_settings" ]]; then
            # Merge base + type overlay
            _claude_merge_settings_json "$base_settings" "$type_settings" "$settings_target"
            echo "  ✓ Built settings.json from base + $project_type overlay"
            settings_profile="base+${project_type}"
        else
            # Copy base only
            cp "$base_settings" "$settings_target"
            echo "  ✓ Copied base settings.json"
            settings_profile="base"
        fi
    fi

    echo ""

    # Step 2: Deploy hooks.conf
    echo "Step 2: Hooks configuration"
    echo "──────────────────────────────"

    local hooks_conf_target="$claude_dir/hooks.conf"
    local hooks_template="default"

    echo "  Select hooks profile:"
    select profile in "default" "strict" "permissive"; do
        case $profile in
            default|strict|permissive)
                hooks_template="$profile"
                break
                ;;
        esac
    done

    local hooks_conf_source="$PLUGIN_DIR/templates/hooks-conf/${hooks_template}.conf"

    if [[ -f "$hooks_conf_target" ]]; then
        echo "  Existing hooks.conf found"
        if wizard_yesno "  Overwrite hooks.conf?" "n"; then
            cp "$hooks_conf_source" "$hooks_conf_target"
            echo "  ✓ Copied $hooks_template hooks.conf"
        else
            echo "  Skipped hooks.conf"
        fi
    else
        cp "$hooks_conf_source" "$hooks_conf_target"

        # Adjust defaults based on project type
        if [[ "$project_type" == "python" ]]; then
            # RUFF_ENABLED already true in default template
            echo "  ✓ Copied $hooks_template hooks.conf (Python defaults)"
        elif [[ "$project_type" == "node" ]]; then
            # Disable Ruff for Node projects - platform-aware sed
            if [[ "$OSTYPE" == "darwin"* ]]; then
                sed -i '' 's/^RUFF_ENABLED=true/RUFF_ENABLED=false/' "$hooks_conf_target"
            else
                sed -i 's/^RUFF_ENABLED=true/RUFF_ENABLED=false/' "$hooks_conf_target"
            fi
            echo "  ✓ Copied $hooks_template hooks.conf (Node defaults)"
        else
            echo "  ✓ Copied $hooks_template hooks.conf"
        fi
    fi

    echo ""

    # Step 3: Create/update CLAUDE.md
    echo "Step 3: Project CLAUDE.md"
    echo "──────────────────────────────"

    local claude_md_target="$project_path/CLAUDE.md"

    if [[ -f "$claude_md_target" ]]; then
        echo "  Existing CLAUDE.md found"
        echo "  Choose action:"
        select action in "Append dotconfigs section" "Skip"; do
            case $action in
                "Append dotconfigs section")
                    cat >> "$claude_md_target" <<EOF

## Project Configuration

Project type: $project_type
Configuration managed by: dotconfigs

For global Claude instructions, see: ~/.claude/CLAUDE.md
EOF
                    echo "  ✓ Appended dotconfigs section to CLAUDE.md"
                    break
                    ;;
                Skip)
                    echo "  Skipped CLAUDE.md"
                    break
                    ;;
            esac
        done
    else
        # Create minimal project CLAUDE.md
        cat > "$claude_md_target" <<EOF
# $(basename "$project_path")

Project type: $project_type

## Configuration

This project uses dotconfigs for Claude Code configuration.
- Settings: .claude/settings.json
- Hooks: .claude/hooks.conf
- Global instructions: ~/.claude/CLAUDE.md
EOF
        echo "  ✓ Created minimal CLAUDE.md"
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

    if ! grep -q "^\.claude-project$" "$git_exclude" 2>/dev/null; then
        echo ".claude-project" >> "$git_exclude"
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

    _claude_write_project_config "$project_path" "$project_type" "$settings_profile" "$hooks_template"

    if [[ $? -eq 0 ]]; then
        echo "  ✓ Saved configuration to .dotconfigs.json"
    else
        echo "  ✗ Failed to save configuration" >&2
    fi

    echo ""

    # Step 6: Ask commit or exclude .dotconfigs.json
    echo "Step 6: Version control for .dotconfigs.json"
    echo "──────────────────────────────"

    if wizard_yesno "  Commit .dotconfigs.json to git?" "y"; then
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
    echo "Created/updated:"
    echo "  - .claude/settings.json (merged from templates)"
    echo "  - .claude/hooks.conf (copy of $hooks_template template)"
    echo "  - CLAUDE.md (project-specific)"
    echo "  - .git/info/exclude (AI artefacts)"
    echo "  - .dotconfigs.json (project configuration)"
    echo ""
}
