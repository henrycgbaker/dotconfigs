# lib/init.sh — Shared init logic for global-init and project-init
# Sourced by dotconfigs entry point.
# Depends on: PLUGINS_DIR (set by entry point)

# Assemble a config JSON from plugin manifests
# Args: scope ("global" or "project")
# Output: JSON to stdout
assemble_from_manifests() {
    local scope="$1"
    local merged="{}"
    local plugin_dir plugin_name manifest section

    for plugin_dir in "$PLUGINS_DIR"/*/; do
        [[ -d "$plugin_dir" ]] || continue
        manifest="$plugin_dir/manifest.json"
        [[ -f "$manifest" ]] || continue

        plugin_name=$(basename "$plugin_dir")

        # Extract the scope section (.global or .project)
        section=$(jq -r --arg s "$scope" '.[$s] // empty' "$manifest")
        [[ -z "$section" ]] && continue

        merged=$(echo "$merged" | jq --arg name "$plugin_name" --argjson modules "$section" '.[$name] = $modules')
    done

    echo "$merged" | jq '.'
}

# Write JSON content with overwrite protection
# Args: output_file, json_content
# Returns: 0 on write, 1 on skip
write_with_overwrite_protection() {
    local output_file="$1"
    local json_content="$2"
    local display_name="$(basename "$(dirname "$output_file")")/$(basename "$output_file")"

    if [[ -f "$output_file" ]]; then
        echo "$display_name already exists."
        local overwrite_answer="n"
        if [[ -t 1 ]]; then
            read -r -p "Overwrite? [y/N] " overwrite_answer </dev/tty
        fi
        case "$overwrite_answer" in
            [yY])
                local backup="$output_file.bak.$(date +%Y%m%d%H%M%S)"
                cp "$output_file" "$backup"
                echo "$json_content" > "$output_file"
                echo "Backed up to $(basename "$backup"), overwrote $display_name"
                ;;
            *)
                echo "Skipped (kept existing $display_name)"
                return 1
                ;;
        esac
    else
        mkdir -p "$(dirname "$output_file")"
        echo "$json_content" > "$output_file"
        echo "Created $display_name"
    fi
    return 0
}

# Prompt to deploy after init (TTY-aware)
# Args: deploy_command [extra_args...]
# Returns: 0 if deployed, 1 if skipped/non-TTY
prompt_deploy() {
    if [[ -t 0 ]] || [[ -t 1 ]]; then
        echo ""
        read -r -p "Deploy now? [Y/n] " deploy_answer </dev/tty
        case "$deploy_answer" in
            [nN]) return 1 ;;
            *)
                echo ""
                "$@"
                return 0
                ;;
        esac
    fi
    return 1
}
