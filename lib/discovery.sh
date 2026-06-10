# lib/discovery.sh — Plugin discovery and content scanning

# Find available plugins in plugins/ directory.
# A plugin is plugins/<name>/manifest.json.
# Args: plugins_dir
# Returns: List of plugin names (one per line, sorted)
discover_plugins() {
    local plugins_dir="$1"

    if [[ ! -d "$plugins_dir" ]]; then
        return 0
    fi

    local manifest_path dir
    find "$plugins_dir" -mindepth 2 -maxdepth 2 -name manifest.json -type f | while read -r manifest_path; do
        dir="${manifest_path%/*}"
        echo "${dir##*/}"
    done | sort
}

# Check if a plugin exists. Single source of truth for "what is a plugin":
# delegates to discover_plugins so the contract is defined in exactly one place.
# Args: plugin, plugins_dir (defaults to $PLUGINS_DIR)
# Returns: 0 if a discovered plugin, 1 otherwise
plugin_exists() {
    local plugin="$1"
    local plugins_dir="${2:-$PLUGINS_DIR}"
    discover_plugins "$plugins_dir" | grep -qx "$plugin"
}

# List all available plugins to stderr
# Args: none (uses $PLUGINS_DIR)
list_available_plugins() {
    echo "Available plugins:" >&2
    discover_plugins "$PLUGINS_DIR" | while read -r plugin; do
        echo "  - $plugin" >&2
    done
}

