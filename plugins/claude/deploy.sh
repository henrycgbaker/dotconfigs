# plugins/claude/deploy.sh — Claude Code configuration deployment
# Sourced by dotconfigs entry point. Do not execute directly.

# Derive plugin directory from this file's location
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ENV_FILE="$DOTCONFIGS_ROOT/.env"

# Internal: Assemble settings.json from templates
# Args: plugin_dir, output_file
_claude_assemble_settings() {
    local plugin_dir="$1"
    local output_file="$2"
    local templates_dir="$plugin_dir/templates/settings"

    # Start with base.json
    local base_file="$templates_dir/base.json"
    if [[ ! -f "$base_file" ]]; then
        echo "Error: base.json template not found" >&2
        return 1
    fi

    # Create temp file for assembly
    local temp_file=$(mktemp)
    cp "$base_file" "$temp_file"

    # Merge Python rules if enabled
    if [[ "${CLAUDE_SETTINGS_PYTHON:-false}" == "true" ]]; then
        local python_file="$templates_dir/python.json"
        if [[ -f "$python_file" ]]; then
            local temp_merge=$(mktemp)
            if command -v jq &> /dev/null; then
                jq -s '.[0] * .[1]' "$temp_file" "$python_file" > "$temp_merge"
            else
                # Fallback: Python-based merge
                python3 <<EOF
import json
with open("$temp_file") as f:
    base = json.load(f)
with open("$python_file") as f:
    overlay = json.load(f)

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
with open("$temp_merge", "w") as f:
    json.dump(result, f, indent=2)
EOF
            fi
            mv "$temp_merge" "$temp_file"
        fi
    fi

    # Merge Node rules if enabled
    if [[ "${CLAUDE_SETTINGS_NODE:-false}" == "true" ]]; then
        local node_file="$templates_dir/node.json"
        if [[ -f "$node_file" ]]; then
            local temp_merge=$(mktemp)
            if command -v jq &> /dev/null; then
                jq -s '.[0] * .[1]' "$temp_file" "$node_file" > "$temp_merge"
            else
                # Fallback: Python-based merge
                python3 <<EOF
import json
with open("$temp_file") as f:
    base = json.load(f)
with open("$node_file") as f:
    overlay = json.load(f)

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
with open("$temp_merge", "w") as f:
    json.dump(result, f, indent=2)
EOF
            fi
            mv "$temp_merge" "$temp_file"
        fi
    fi

    # Merge hooks.json if hooks are enabled
    if [[ ${#CLAUDE_HOOKS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        local hooks_file="$templates_dir/hooks.json"
        if [[ -f "$hooks_file" ]]; then
            local temp_merge=$(mktemp)
            if command -v jq &> /dev/null; then
                jq -s '.[0] * .[1]' "$temp_file" "$hooks_file" > "$temp_merge"
            else
                # Fallback: Python-based merge
                python3 <<EOF
import json
with open("$temp_file") as f:
    base = json.load(f)
with open("$hooks_file") as f:
    overlay = json.load(f)

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
with open("$temp_merge", "w") as f:
    json.dump(result, f, indent=2)
EOF
            fi
            mv "$temp_merge" "$temp_file"
        fi
    fi

    # Move assembled result to output
    mv "$temp_file" "$output_file"
    return 0
}

# Internal: Apply CLAUDE.md exclusion to .git/info/exclude
# Args: repo_path
_claude_apply_md_exclusion() {
    local repo_path="$1"
    local exclude_file="$repo_path/.git/info/exclude"

    # Check if CLAUDE.md exclusion is enabled globally
    if [[ "${CLAUDE_MD_EXCLUDE_GLOBAL:-false}" != "true" ]]; then
        return 0
    fi

    # Get exclusion pattern (default: CLAUDE.md)
    local pattern="${CLAUDE_MD_EXCLUDE_PATTERN:-CLAUDE.md}"

    if [[ "$dry_run" == "true" ]]; then
        echo "Applying CLAUDE.md exclusion..."
        if [[ ! -f "$exclude_file" ]] || ! grep -q "^${pattern}$" "$exclude_file" 2>/dev/null; then
            echo "  Would add: $pattern"
        else
            echo "  Already excluded: $pattern"
        fi
        if [[ ! -f "$exclude_file" ]] || ! grep -q "^\.claude/$" "$exclude_file" 2>/dev/null; then
            echo "  Would add: .claude/"
        else
            echo "  Already excluded: .claude/"
        fi
        return 0
    fi

    # Create .git/info/exclude if it doesn't exist
    if [[ ! -f "$exclude_file" ]]; then
        mkdir -p "$(dirname "$exclude_file")"
        touch "$exclude_file"
    fi

    echo "Applying CLAUDE.md exclusion..."

    # Add pattern if not present
    if ! grep -q "^${pattern}$" "$exclude_file" 2>/dev/null; then
        echo "$pattern" >> "$exclude_file"
        echo "  ✓ Added $pattern to .git/info/exclude"
    else
        echo "  Already excluded: $pattern"
    fi

    # Add .claude/ if not present
    if ! grep -q "^\.claude/$" "$exclude_file" 2>/dev/null; then
        echo ".claude/" >> "$exclude_file"
        echo "  ✓ Added .claude/ to .git/info/exclude"
    else
        echo "  Already excluded: .claude/"
    fi
}

# Internal: Build CLAUDE.md from enabled template sections
# Args: plugin_dir, deploy_target, enabled_sections...
_claude_build_md() {
    local plugin_dir="$1"
    local deploy_target="$2"
    shift 2
    local enabled_sections=("$@")

    local templates_dir="$plugin_dir/templates/claude-md"
    local output_file="$deploy_target/CLAUDE.md"

    # Clear output file
    > "$output_file"

    # Read templates in numeric order and concatenate enabled ones
    local first_section=true
    for template_file in "$templates_dir"/*.md; do
        if [[ ! -f "$template_file" ]]; then
            continue
        fi

        # Extract section name from filename (01-communication.md → communication)
        local filename=$(basename "$template_file")
        local section_name=$(echo "$filename" | sed -E 's/^[0-9]+-(.*)\.md$/\1/')

        # Check if section is enabled
        local section_enabled=false
        for enabled in "${enabled_sections[@]}"; do
            if [[ "$enabled" == "$section_name" ]]; then
                section_enabled=true
                break
            fi
        done

        if [[ "$section_enabled" == "true" ]]; then
            # Add blank line separator between sections (but not before first)
            if [[ "$first_section" == "false" ]]; then
                echo "" >> "$output_file"
            fi
            first_section=false

            # Append template content
            cat "$template_file" >> "$output_file"
        fi
    done

    echo "  ✓ Built CLAUDE.md from $(echo ${enabled_sections[@]} | wc -w | tr -d ' ') sections"
}

# Internal: Load and parse CLAUDE_* config from .env
# Returns: 1 if .env doesn't exist or config invalid, 0 otherwise
# Sets global variables: CLAUDE_DEPLOY_TARGET, CLAUDE_SETTINGS_ENABLED, etc.
_claude_load_config() {
    if [[ ! -f "$ENV_FILE" ]]; then
        echo "Error: No configuration found. Run 'dotconfigs setup claude' first." >&2
        return 1
    fi

    # Source .env
    source "$ENV_FILE"

    # Verify required keys exist
    if [[ -z "${CLAUDE_DEPLOY_TARGET:-}" ]]; then
        echo "Error: CLAUDE_DEPLOY_TARGET not set in .env" >&2
        return 1
    fi

    # Parse space-separated strings back to arrays
    if [[ -n "${CLAUDE_MD_SECTIONS:-}" ]]; then
        IFS=' ' read -ra CLAUDE_MD_SECTIONS_ARRAY <<< "$CLAUDE_MD_SECTIONS"
    else
        CLAUDE_MD_SECTIONS_ARRAY=()
    fi

    if [[ -n "${CLAUDE_HOOKS_ENABLED:-}" ]]; then
        IFS=' ' read -ra CLAUDE_HOOKS_ENABLED_ARRAY <<< "$CLAUDE_HOOKS_ENABLED"
    else
        CLAUDE_HOOKS_ENABLED_ARRAY=()
    fi

    if [[ -n "${CLAUDE_SKILLS_ENABLED:-}" ]]; then
        IFS=' ' read -ra CLAUDE_SKILLS_ENABLED_ARRAY <<< "$CLAUDE_SKILLS_ENABLED"
    else
        CLAUDE_SKILLS_ENABLED_ARRAY=()
    fi

    return 0
}

# Status reporting — called by dotconfigs status command
# Usage: plugin_claude_status
plugin_claude_status() {
    # Load configuration from .env
    if ! _claude_load_config; then
        printf "%b %s\n" "$(colour_red "claude")" "not configured"
        return 0
    fi

    # Count states for overall status
    local count_ok=0
    local count_drift=0
    local count_missing=0
    local state

    # Collect all files to check
    declare -a files_to_check=()
    declare -a file_states=()
    declare -a file_names=()

    # Add settings.json if enabled
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/settings.json|$DOTCONFIGS_ROOT/settings.json|settings.json")
    fi

    # Add CLAUDE.md (special case: generated file, not symlink)
    if [[ ${#CLAUDE_MD_SECTIONS_ARRAY[@]} -gt 0 ]]; then
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/CLAUDE.md|generated|CLAUDE.md")
    fi

    # Add hooks
    for hook in "${CLAUDE_HOOKS_ENABLED_ARRAY[@]}"; do
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/hooks/$hook|$PLUGIN_DIR/hooks/$hook|hooks/$hook")
    done

    # Add skills
    for skill in "${CLAUDE_SKILLS_ENABLED_ARRAY[@]}"; do
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/commands/${skill}.md|$PLUGIN_DIR/commands/${skill}.md|commands/${skill}.md")
    done

    # Check each file and count states
    for file_spec in "${files_to_check[@]}"; do
        IFS='|' read -r target_path expected_source display_name <<< "$file_spec"

        if [[ "$expected_source" == "generated" ]]; then
            # Special case for CLAUDE.md (generated file)
            if [[ -f "$target_path" ]]; then
                state="deployed"
                ((count_ok++))
            else
                state="not-deployed"
                ((count_missing++))
            fi
        else
            # Regular symlink check
            state=$(check_file_state "$target_path" "$expected_source" "$DOTCONFIGS_ROOT")
            case "$state" in
                deployed)
                    ((count_ok++))
                    ;;
                drifted-*)
                    ((count_drift++))
                    ;;
                not-deployed)
                    ((count_missing++))
                    ;;
            esac
        fi

        file_states+=("$state")
        file_names+=("$display_name")
    done

    # Print plugin header with overall status
    if [[ $count_drift -gt 0 ]]; then
        printf "%b %b %s\n" "$(colour_yellow "claude")" "$(colour_yellow "$SYMBOL_DRIFT")" "deployed (drift detected)"
    elif [[ $count_missing -gt 0 ]]; then
        printf "%b %b %s\n" "$(colour_yellow "claude")" "$(colour_yellow "$SYMBOL_DRIFT")" "partially deployed"
    else
        printf "%b %b %s\n" "$(colour_green "claude")" "$(colour_green "$SYMBOL_OK")" "deployed"
    fi

    # Print per-file details
    for i in "${!file_names[@]}"; do
        _print_file_status "${file_names[$i]}" "${file_states[$i]}"
    done

    return 0
}

# Main entry point — called by dotconfigs CLI
# Usage: plugin_claude_deploy [--interactive] [--dry-run] [--force]
plugin_claude_deploy() {
    local interactive_mode="false"
    local dry_run=false

    # Parse flags
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --interactive)
                interactive_mode="true"
                shift
                ;;
            --force)
                interactive_mode="force"
                shift
                ;;
            --dry-run)
                dry_run=true
                shift
                ;;
            *)
                echo "Error: Unknown option $1" >&2
                return 1
                ;;
        esac
    done

    # Load configuration from .env
    if ! _claude_load_config; then
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
        echo "  DRY RUN: Previewing Claude Code deployment"
    else
        echo "  Deploying Claude Code configuration to: $CLAUDE_DEPLOY_TARGET"
    fi
    echo "═══════════════════════════════════════════════════════════"
    echo ""

    # Create deploy target directory if it doesn't exist
    if [[ ! -d "$CLAUDE_DEPLOY_TARGET" ]]; then
        if [[ "$dry_run" == "true" ]]; then
            echo "  Would create $CLAUDE_DEPLOY_TARGET"
            ((files_created++))
        else
            mkdir -p "$CLAUDE_DEPLOY_TARGET"
            echo "  ✓ Created $CLAUDE_DEPLOY_TARGET"
            ((files_created++))
        fi
    fi

    # 1. Build and symlink settings.json
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        echo "Building settings.json..."

        # Assemble settings.json from templates
        local settings_source="$DOTCONFIGS_ROOT/settings.json"
        if [[ "$dry_run" != "true" ]]; then
            _claude_assemble_settings "$PLUGIN_DIR" "$settings_source"
            echo "  ✓ Assembled settings.json from templates"
        else
            echo "  Would assemble: base"
            [[ "${CLAUDE_SETTINGS_PYTHON:-false}" == "true" ]] && echo "  Would assemble: + python"
            [[ "${CLAUDE_SETTINGS_NODE:-false}" == "true" ]] && echo "  Would assemble: + node"
            [[ ${#CLAUDE_HOOKS_ENABLED_ARRAY[@]} -gt 0 ]] && echo "  Would assemble: + hooks"
        fi

        echo "Deploying settings.json..."
        local state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/settings.json" "$settings_source" "$DOTCONFIGS_ROOT")

        if [[ "$dry_run" == "true" ]]; then
            case "$state" in
                deployed)
                    echo "  Unchanged: settings.json"
                    ((files_unchanged++))
                    ;;
                not-deployed)
                    echo "  Would link: settings.json"
                    ((files_created++))
                    ;;
                drifted-*)
                    if [[ "$interactive_mode" == "force" ]]; then
                        echo "  Would overwrite: settings.json (--force)"
                        ((files_updated++))
                    else
                        echo "  Would prompt: conflict at settings.json"
                        ((files_skipped++))
                    fi
                    ;;
            esac
        else
            case "$state" in
                deployed)
                    echo "  Unchanged: settings.json"
                    ((files_unchanged++))
                    ;;
                *)
                    if backup_and_link "$DOTCONFIGS_ROOT/settings.json" "$CLAUDE_DEPLOY_TARGET/settings.json" "settings.json" "$interactive_mode"; then
                        if [[ "$state" == "not-deployed" ]]; then
                            ((files_created++))
                        else
                            ((files_updated++))
                        fi
                    else
                        ((files_skipped++))
                    fi
                    ;;
            esac
        fi
    fi

    # 2. Build and write CLAUDE.md
    if [[ ${#CLAUDE_MD_SECTIONS_ARRAY[@]} -gt 0 ]]; then
        echo "Building CLAUDE.md..."
        if [[ "$dry_run" == "true" ]]; then
            if [[ -f "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" ]]; then
                echo "  Would update: CLAUDE.md"
                ((files_updated++))
            else
                echo "  Would create: CLAUDE.md"
                ((files_created++))
            fi
        else
            local existed=false
            if [[ -f "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" ]]; then
                existed=true
            fi
            _claude_build_md "$PLUGIN_DIR" "$CLAUDE_DEPLOY_TARGET" "${CLAUDE_MD_SECTIONS_ARRAY[@]}"
            if [[ "$existed" == "true" ]]; then
                ((files_updated++))
            else
                ((files_created++))
            fi
        fi
    fi

    # 3. Symlink Claude Code hooks
    if [[ ${#CLAUDE_HOOKS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        echo "Deploying Claude Code hooks..."
        if [[ "$dry_run" != "true" ]]; then
            mkdir -p "$CLAUDE_DEPLOY_TARGET/hooks"
        fi

        for hook in "${CLAUDE_HOOKS_ENABLED_ARRAY[@]}"; do
            local target="$CLAUDE_DEPLOY_TARGET/hooks/$hook"
            local source="$PLUGIN_DIR/hooks/$hook"
            local state=$(check_file_state "$target" "$source" "$DOTCONFIGS_ROOT")

            if [[ "$dry_run" == "true" ]]; then
                case "$state" in
                    deployed)
                        echo "  Unchanged: hooks/$hook"
                        ((files_unchanged++))
                        ;;
                    not-deployed)
                        echo "  Would link: hooks/$hook"
                        ((files_created++))
                        ;;
                    drifted-*)
                        if [[ "$interactive_mode" == "force" ]]; then
                            echo "  Would overwrite: hooks/$hook (--force)"
                            ((files_updated++))
                        else
                            echo "  Would prompt: conflict at hooks/$hook"
                            ((files_skipped++))
                        fi
                        ;;
                esac
            else
                case "$state" in
                    deployed)
                        echo "  Unchanged: hooks/$hook"
                        ((files_unchanged++))
                        ;;
                    *)
                        if backup_and_link "$source" "$target" "hooks/$hook" "$interactive_mode"; then
                            if [[ "$state" == "not-deployed" ]]; then
                                ((files_created++))
                            else
                                ((files_updated++))
                            fi
                        else
                            ((files_skipped++))
                        fi
                        ;;
                esac
            fi
        done
    fi

    # 4. Symlink skills (commands)
    if [[ ${#CLAUDE_SKILLS_ENABLED_ARRAY[@]} -gt 0 ]]; then
        echo "Deploying skills..."
        if [[ "$dry_run" != "true" ]]; then
            mkdir -p "$CLAUDE_DEPLOY_TARGET/commands"
        fi

        for skill in "${CLAUDE_SKILLS_ENABLED_ARRAY[@]}"; do
            local target="$CLAUDE_DEPLOY_TARGET/commands/${skill}.md"
            local source="$PLUGIN_DIR/commands/${skill}.md"
            local state=$(check_file_state "$target" "$source" "$DOTCONFIGS_ROOT")

            if [[ "$dry_run" == "true" ]]; then
                case "$state" in
                    deployed)
                        echo "  Unchanged: commands/${skill}.md"
                        ((files_unchanged++))
                        ;;
                    not-deployed)
                        echo "  Would link: commands/${skill}.md"
                        ((files_created++))
                        ;;
                    drifted-*)
                        if [[ "$interactive_mode" == "force" ]]; then
                            echo "  Would overwrite: commands/${skill}.md (--force)"
                            ((files_updated++))
                        else
                            echo "  Would prompt: conflict at commands/${skill}.md"
                            ((files_skipped++))
                        fi
                        ;;
                esac
            else
                case "$state" in
                    deployed)
                        echo "  Unchanged: commands/${skill}.md"
                        ((files_unchanged++))
                        ;;
                    *)
                        if backup_and_link "$source" "$target" "commands/${skill}.md" "$interactive_mode"; then
                            if [[ "$state" == "not-deployed" ]]; then
                                ((files_created++))
                            else
                                ((files_updated++))
                            fi
                        else
                            ((files_skipped++))
                        fi
                        ;;
                esac
            fi
        done
    fi

    # 5. Install GSD framework
    if [[ "${CLAUDE_GSD_INSTALL:-false}" == "true" ]]; then
        echo "Installing GSD framework..."
        if [[ "$dry_run" == "true" ]]; then
            echo "  Would run: npx get-shit-done-cc --claude --global"
        else
            npx get-shit-done-cc --claude --global
            echo "  ✓ GSD framework installed"
        fi
    fi

    # 6. Apply CLAUDE.md exclusion
    _claude_apply_md_exclusion "$DOTCONFIGS_ROOT"

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
