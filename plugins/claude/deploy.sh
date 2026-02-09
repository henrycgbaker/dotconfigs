# plugins/claude/deploy.sh — Claude Code configuration deployment
# Sourced by dotconfigs entry point. Do not execute directly.

# Derive plugin directory from this file's location
PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCONFIGS_ROOT="$(cd "$PLUGIN_DIR/../.." && pwd)"
ENV_FILE="$DOTCONFIGS_ROOT/.env"

# Internal: Assemble settings.json from template
# Args: plugin_dir, output_file
_claude_assemble_settings() {
    local plugin_dir="$1"
    local output_file="$2"
    local template="$plugin_dir/templates/settings/settings-template.json"

    if [[ ! -f "$template" ]]; then
        echo "Error: settings-template.json not found" >&2
        return 1
    fi

    cp "$template" "$output_file"
    return 0
}

# Internal: Apply CLAUDE.md exclusion
# Args: repo_path
# Respects CLAUDE_MD_EXCLUDE_DEST: "exclude" (.git/info/exclude) or "gitignore" (.gitignore)
_claude_apply_md_exclusion() {
    local repo_path="$1"
    local dest="${CLAUDE_MD_EXCLUDE_DEST:-exclude}"
    local exclude_file
    local dest_label

    if [[ "$dest" == "gitignore" ]]; then
        exclude_file="$repo_path/.gitignore"
        dest_label=".gitignore"
    else
        exclude_file="$repo_path/.git/info/exclude"
        dest_label=".git/info/exclude"
    fi

    # Check if CLAUDE.md exclusion is enabled globally
    if [[ "${CLAUDE_MD_EXCLUDE_GLOBAL:-false}" != "true" ]]; then
        return 0
    fi

    # Build list of patterns to exclude
    local raw_pattern="${CLAUDE_MD_EXCLUDE_PATTERN:-CLAUDE.md}"
    local patterns=()
    case "$raw_pattern" in
        both|*$'\n'*)
            # "both" keyword or legacy multiline value
            patterns=("CLAUDE.md" "**/CLAUDE.md")
            ;;
        *)
            patterns=("$raw_pattern")
            ;;
    esac
    # Always include .claude/
    patterns+=(".claude/")

    if [[ "$dry_run" == "true" ]]; then
        echo "Applying CLAUDE.md exclusion to $dest_label..."
        for p in "${patterns[@]}"; do
            if [[ ! -f "$exclude_file" ]] || ! grep -qF "$p" "$exclude_file" 2>/dev/null; then
                echo "  Would add: $p"
            else
                echo "  Already excluded: $p"
            fi
        done
        return 0
    fi

    # Create exclude file if it doesn't exist
    if [[ ! -f "$exclude_file" ]]; then
        mkdir -p "$(dirname "$exclude_file")"
        touch "$exclude_file"
    fi

    echo "Applying CLAUDE.md exclusion to $dest_label..."

    for p in "${patterns[@]}"; do
        if ! grep -qF "$p" "$exclude_file" 2>/dev/null; then
            echo "$p" >> "$exclude_file"
            echo "  ✓ Added $p to $dest_label"
        else
            echo "  Already excluded: $p"
        fi
    done
}

# Internal: Build CLAUDE.md from enabled template sections into plugin dir
# Args: plugin_dir, enabled_sections...
# Writes to: $plugin_dir/CLAUDE.md (gitignored assembled copy)
_claude_build_md() {
    local plugin_dir="$1"
    shift
    local enabled_sections=("$@")

    local templates_dir="$plugin_dir/templates/claude-md"
    local output_file="$plugin_dir/CLAUDE.md"

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
        echo "Error: No configuration found. Run 'dotconfigs setup' then 'dotconfigs global-configs claude' first." >&2
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
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/settings.json|$PLUGIN_DIR/settings.json|settings.json")
    fi

    # Add CLAUDE.md (symlinked from assembled copy in plugin dir)
    if [[ ${#CLAUDE_MD_SECTIONS_ARRAY[@]} -gt 0 ]]; then
        files_to_check+=("$CLAUDE_DEPLOY_TARGET/CLAUDE.md|$PLUGIN_DIR/CLAUDE.md|CLAUDE.md")
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

        state=$(check_file_state "$target_path" "$expected_source" "$DOTCONFIGS_ROOT")
        case "$state" in
            deployed)
                count_ok=$((count_ok + 1))
                ;;
            drifted-*)
                count_drift=$((count_drift + 1))
                ;;
            not-deployed)
                count_missing=$((count_missing + 1))
                ;;
        esac

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
            files_created=$((files_created + 1))
        else
            mkdir -p "$CLAUDE_DEPLOY_TARGET"
            echo "  ✓ Created $CLAUDE_DEPLOY_TARGET"
            files_created=$((files_created + 1))
        fi
    fi

    # 1. Build and symlink settings.json
    if [[ "${CLAUDE_SETTINGS_ENABLED:-false}" == "true" ]]; then
        local settings_source="$PLUGIN_DIR/settings.json"

        # Only create from template if assembled copy doesn't exist yet
        # (preserves user's manual edits to their personal copy)
        if [[ ! -f "$settings_source" ]]; then
            echo "Creating settings.json from template..."
            if [[ "$dry_run" != "true" ]]; then
                _claude_assemble_settings "$PLUGIN_DIR" "$settings_source"
                echo "  ✓ Created from settings-template.json"
            else
                echo "  Would create from: settings-template.json"
            fi
        fi

        echo "Deploying settings.json..."
        local state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/settings.json" "$settings_source" "$DOTCONFIGS_ROOT")

        if [[ "$dry_run" == "true" ]]; then
            case "$state" in
                deployed)
                    echo "  Unchanged: settings.json → $CLAUDE_DEPLOY_TARGET/settings.json"
                    files_unchanged=$((files_unchanged + 1))
                    ;;
                not-deployed)
                    echo "  Would link: settings.json → $CLAUDE_DEPLOY_TARGET/settings.json"
                    files_created=$((files_created + 1))
                    ;;
                drifted-*)
                    if [[ "$interactive_mode" == "force" ]]; then
                        echo "  Would overwrite: settings.json (--force)"
                        files_updated=$((files_updated + 1))
                    else
                        echo "  Would prompt: conflict at settings.json"
                        files_skipped=$((files_skipped + 1))
                    fi
                    ;;
            esac
        else
            case "$state" in
                deployed)
                    echo "  Unchanged: settings.json → $CLAUDE_DEPLOY_TARGET/settings.json"
                    files_unchanged=$((files_unchanged + 1))
                    ;;
                *)
                    if backup_and_link "$PLUGIN_DIR/settings.json" "$CLAUDE_DEPLOY_TARGET/settings.json" "settings.json" "$interactive_mode"; then
                        if [[ "$state" == "not-deployed" ]]; then
                            files_created=$((files_created + 1))
                        else
                            files_updated=$((files_updated + 1))
                        fi
                    else
                        files_skipped=$((files_skipped + 1))
                    fi
                    ;;
            esac
        fi
    fi

    # 2. Build and write CLAUDE.md
    if [[ ${#CLAUDE_MD_SECTIONS_ARRAY[@]} -gt 0 ]]; then
        local claude_md_source="$PLUGIN_DIR/CLAUDE.md"

        # Always rebuild assembled copy (generated from templates)
        local md_old_hash=""
        [[ -f "$claude_md_source" ]] && md_old_hash=$(cksum "$claude_md_source" 2>/dev/null | cut -d' ' -f1)

        if [[ "$dry_run" != "true" ]]; then
            _claude_build_md "$PLUGIN_DIR" "${CLAUDE_MD_SECTIONS_ARRAY[@]}"
        fi

        local md_new_hash=""
        [[ -f "$claude_md_source" ]] && md_new_hash=$(cksum "$claude_md_source" 2>/dev/null | cut -d' ' -f1)
        local md_content_changed=false
        [[ "$md_old_hash" != "$md_new_hash" ]] && md_content_changed=true

        echo "Deploying CLAUDE.md..."
        local state=$(check_file_state "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" "$claude_md_source" "$DOTCONFIGS_ROOT")

        if [[ "$dry_run" == "true" ]]; then
            case "$state" in
                deployed)
                    echo "  Unchanged: CLAUDE.md → $CLAUDE_DEPLOY_TARGET/CLAUDE.md"
                    files_unchanged=$((files_unchanged + 1))
                    ;;
                not-deployed)
                    echo "  Would link: CLAUDE.md → $CLAUDE_DEPLOY_TARGET/CLAUDE.md"
                    files_created=$((files_created + 1))
                    ;;
                drifted-*)
                    if [[ "$interactive_mode" == "force" ]]; then
                        echo "  Would overwrite: CLAUDE.md (--force)"
                        files_updated=$((files_updated + 1))
                    else
                        echo "  Would prompt: conflict at CLAUDE.md"
                        files_skipped=$((files_skipped + 1))
                    fi
                    ;;
            esac
        else
            case "$state" in
                deployed)
                    if [[ "$md_content_changed" == "true" ]]; then
                        echo "  Updated: CLAUDE.md → $CLAUDE_DEPLOY_TARGET/CLAUDE.md"
                        files_updated=$((files_updated + 1))
                    else
                        echo "  Unchanged: CLAUDE.md → $CLAUDE_DEPLOY_TARGET/CLAUDE.md"
                        files_unchanged=$((files_unchanged + 1))
                    fi
                    ;;
                *)
                    # Handle broken symlink at deploy target
                    if [[ -L "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" && ! -e "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" ]]; then
                        rm -f "$CLAUDE_DEPLOY_TARGET/CLAUDE.md"
                    fi
                    if backup_and_link "$claude_md_source" "$CLAUDE_DEPLOY_TARGET/CLAUDE.md" "CLAUDE.md" "$interactive_mode"; then
                        if [[ "$state" == "not-deployed" ]]; then
                            files_created=$((files_created + 1))
                        else
                            files_updated=$((files_updated + 1))
                        fi
                    else
                        files_skipped=$((files_skipped + 1))
                    fi
                    ;;
            esac
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
                        files_unchanged=$((files_unchanged + 1))
                        ;;
                    not-deployed)
                        echo "  Would link: hooks/$hook"
                        files_created=$((files_created + 1))
                        ;;
                    drifted-*)
                        if [[ "$interactive_mode" == "force" ]]; then
                            echo "  Would overwrite: hooks/$hook (--force)"
                            files_updated=$((files_updated + 1))
                        else
                            echo "  Would prompt: conflict at hooks/$hook"
                            files_skipped=$((files_skipped + 1))
                        fi
                        ;;
                esac
            else
                case "$state" in
                    deployed)
                        echo "  Unchanged: hooks/$hook → $target"
                        files_unchanged=$((files_unchanged + 1))
                        ;;
                    *)
                        if backup_and_link "$source" "$target" "hooks/$hook" "$interactive_mode"; then
                            if [[ "$state" == "not-deployed" ]]; then
                                files_created=$((files_created + 1))
                            else
                                files_updated=$((files_updated + 1))
                            fi
                        else
                            files_skipped=$((files_skipped + 1))
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
                        files_unchanged=$((files_unchanged + 1))
                        ;;
                    not-deployed)
                        echo "  Would link: commands/${skill}.md"
                        files_created=$((files_created + 1))
                        ;;
                    drifted-*)
                        if [[ "$interactive_mode" == "force" ]]; then
                            echo "  Would overwrite: commands/${skill}.md (--force)"
                            files_updated=$((files_updated + 1))
                        else
                            echo "  Would prompt: conflict at commands/${skill}.md"
                            files_skipped=$((files_skipped + 1))
                        fi
                        ;;
                esac
            else
                case "$state" in
                    deployed)
                        echo "  Unchanged: commands/${skill}.md → $target"
                        files_unchanged=$((files_unchanged + 1))
                        ;;
                    *)
                        if backup_and_link "$source" "$target" "commands/${skill}.md" "$interactive_mode"; then
                            if [[ "$state" == "not-deployed" ]]; then
                                files_created=$((files_created + 1))
                            else
                                files_updated=$((files_updated + 1))
                            fi
                        else
                            files_skipped=$((files_skipped + 1))
                        fi
                        ;;
                esac
            fi
        done
    fi

    # 5. Apply CLAUDE.md exclusion
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
