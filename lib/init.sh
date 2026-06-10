# lib/init.sh — Shared init logic for `init` (machine and project).
# Sourced by dotconfigs entry point.
# Depends on: PLUGINS_DIR (set by entry point), _merged_manifest (lib/deploy.sh)

# Seed a deploy.json selection (the toggle board) for a scope from the plugin
# catalogues. Lists every catalogued item that has a target in this scope, keyed
# plugin -> category -> name, with its `default` as the on/off value. The user
# edits this file to toggle what gets deployed on this instance.
# Args: scope ("machine" or "project")
# Output: JSON to stdout
seed_deploy_json() {
    local scope="$1"
    jq -n --argjson m "$(_merged_manifest "$PLUGINS_DIR")" --arg scope "$scope" '
        $m | to_entries
        | map({ key: .key, value: (
            .value | to_entries
            | map({ key: .key, value: (
                .value | to_entries
                | map( .key as $n | .value as $e
                       | (($e.target | if type=="array" then . else [.] end)
                          | map(if test("^[~/]") then "machine" else "project" end)
                          | index($scope)) as $has
                       | select($has != null)
                       | { key: $n, value: (
                           if ($e.checks != null)
                           then { enabled: ($e.default // false),
                                  checks: ($e.checks | to_entries
                                           | map({ key: .key, value: (.value.default // false) })
                                           | from_entries) }
                           else ($e.default // false)
                           end) } )
                | from_entries ) })
            | map(select(.value | length > 0))
            | from_entries ) })
        | map(select(.value | length > 0))
        | from_entries
    '
}

# Write JSON content with overwrite protection
# Args: output_file, json_content
# Returns: 0 on write, 1 on skip
write_with_overwrite_protection() {
    local output_file="$1"
    local json_content="$2"
    local force="${3:-false}"
    local display_name="$(basename "$(dirname "$output_file")")/$(basename "$output_file")"

    if [[ -f "$output_file" ]]; then
        # Decide whether to overwrite: --force skips the prompt; otherwise ask
        # (default no, and no on a non-TTY).
        local proceed="false" suffix=""
        if [[ "$force" == "true" ]]; then
            proceed="true"
            suffix=" (--force)"
        else
            echo "$display_name already exists."
            local overwrite_answer="n"
            if [[ -t 1 ]]; then
                read -r -p "Overwrite? [y/N] " overwrite_answer </dev/tty
            fi
            if [[ "$overwrite_answer" == [yY] ]]; then
                proceed="true"
            fi
        fi

        if [[ "$proceed" != "true" ]]; then
            echo "Skipped (kept existing $display_name)"
            return 1
        fi
        local backup="$output_file.bak.$(date +%Y%m%d%H%M%S)"
        cp "$output_file" "$backup"
        echo "$json_content" > "$output_file"
        echo "Backed up to $(basename "$backup"), overwrote $display_name$suffix"
    else
        mkdir -p "$(dirname "$output_file")"
        echo "$json_content" > "$output_file"
        echo "Created $display_name"
    fi
    return 0
}
