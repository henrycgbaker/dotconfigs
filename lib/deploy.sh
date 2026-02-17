# lib/deploy.sh — Generic JSON-driven deployment engine
# Sourced by dotconfigs entry point.
# Depends on: lib/symlinks.sh (backup_and_link, is_dotconfigs_owned, link_file)

# Check if jq is installed
# Returns: 0 if installed, 1 with install instructions if not
check_jq() {
    if ! command -v jq &>/dev/null; then
        echo "Error: jq is required but not installed."
        echo ""
        echo "Install instructions:"
        echo "  macOS:   brew install jq"
        echo "  Ubuntu:  sudo apt-get install jq"
        echo "  Fedora:  sudo dnf install jq"
        echo ""
        return 1
    fi
    return 0
}

# Expand tilde in path to $HOME
# Args: path_with_tilde
# Returns: expanded path via stdout
expand_tilde() {
    echo "${1/#\~/$HOME}"
}

# Parse all modules from JSON config recursively
# Args: config_file
# Returns: tab-separated lines: source\ttarget\tmethod\tinclude_csv
parse_modules() {
    local config_file="$1"

    # Use jq recursive descent to find all objects with source+target
    jq -r '.. | select(type == "object") | select(has("source") and has("target")) | [.source, .target, .method, (if has("include") then ((.include // []) - (.exclude // []) | if length == 0 then "__NONE__" else join(",") end) else "" end)] | @tsv' "$config_file" 2>/dev/null || true
}

# Parse modules from a specific group in JSON config
# Args: config_file, group_key
# Returns: tab-separated lines: source\ttarget\tmethod\tinclude_csv
parse_modules_in_group() {
    local config_file="$1"
    local group_key="$2"

    # If no group key, parse all modules
    if [[ -z "$group_key" ]]; then
        parse_modules "$config_file"
        return
    fi

    # Filter to specific group first, then recursive descent
    jq -r --arg group "$group_key" '.[$group] | .. | select(type == "object") | select(has("source") and has("target")) | [.source, .target, .method, (if has("include") then ((.include // []) - (.exclude // []) | if length == 0 then "__NONE__" else join(",") end) else "" end)] | @tsv' "$config_file" 2>/dev/null || true
}

# Remove stale symlinks from a target directory after deploy
# Removes: dotconfigs-owned symlinks not in deployed set, broken/dangling symlinks
# Preserves: foreign regular files, foreign valid symlinks
# Args: target_dir, deployed_csv (comma-separated expected filenames), dotconfigs_root, dry_run
# Uses global `removed` counter
cleanup_stale_in_directory() {
    local target_dir="$1"
    local deployed_csv="$2"
    local dotconfigs_root="$3"
    local dry_run="$4"
    local item
    local item_name
    local is_expected

    # Target dir doesn't exist — nothing to clean
    if [[ ! -d "$target_dir" ]]; then
        return
    fi

    # Parse deployed_csv into array (bash 3.2 compatible)
    local expected_files=()
    if [[ -n "$deployed_csv" ]]; then
        local IFS=','
        for item_name in $deployed_csv; do
            expected_files+=("$item_name")
        done
        unset IFS
    fi

    # Iterate items in target dir (use both -e and -L to catch broken symlinks)
    for item in "$target_dir"/*; do
        # Handle empty directory (glob returns literal pattern)
        [[ ! -e "$item" && ! -L "$item" ]] && continue

        item_name=$(basename "$item")

        # Check if this item is in the expected set
        is_expected=false
        for expected in "${expected_files[@]}"; do
            if [[ "$expected" == "$item_name" ]]; then
                is_expected=true
                break
            fi
        done

        [[ "$is_expected" == "true" ]] && continue

        # Item is not in the expected deploy set — check if we should remove it
        if [[ -L "$item" && ! -e "$item" ]]; then
            # Broken/dangling symlink — only remove if it pointed into dotconfigs
            local raw_target
            raw_target=$(readlink "$item" 2>/dev/null)
            if [[ "$raw_target" == "$dotconfigs_root"* ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    echo "  Would remove broken symlink: $item_name"
                else
                    rm -f "$item"
                    echo "  ✓ Removed broken symlink: $item_name"
                fi
                eval "removed=\$(( \$removed + 1 ))"
            fi
        elif is_dotconfigs_owned "$item" "$dotconfigs_root" 2>/dev/null; then
            # Stale dotconfigs-owned symlink — remove
            if [[ "$dry_run" == "true" ]]; then
                echo "  Would remove stale: $item_name"
            else
                rm -f "$item"
                echo "  ✓ Removed stale: $item_name"
            fi
            eval "removed=\$(( \$removed + 1 ))"
        fi
        # Otherwise: foreign file or foreign valid symlink — leave it alone
    done
}

# Deploy files from a directory source
# Args: source_dir, target_dir, include_csv, dotconfigs_root, dry_run, interactive_mode
# Returns: Status counts via global counters
deploy_directory_files() {
    local source_dir="$1"
    local target_dir="$2"
    local include_csv="$3"
    local dotconfigs_root="$4"
    local dry_run="$5"
    local interactive_mode="$6"
    local file
    local file_name
    local target_file
    local status

    # All items excluded — deploy nothing, but still clean up stale entries
    if [[ "$include_csv" == "__NONE__" ]]; then
        cleanup_stale_in_directory "$target_dir" "" "$dotconfigs_root" "$dry_run"
        return
    fi

    # Create target directory unless dry-run
    if [[ "$dry_run" != "true" ]]; then
        # If target path exists but isn't a directory (e.g. dangling symlink, file), remove it
        # Note: -d follows symlinks, so symlinks to valid directories are preserved
        if [[ ! -d "$target_dir" && ( -L "$target_dir" || -e "$target_dir" ) ]]; then
            rm -f "$target_dir"
        fi
        mkdir -p "$target_dir"
    fi

    # Parse include list if provided
    if [[ -n "$include_csv" ]]; then
        # Split CSV into array (bash 3.2 compatible - no readarray)
        local include_files=()
        local IFS=','
        for file_name in $include_csv; do
            include_files+=("$file_name")
        done
        unset IFS

        # Deploy only included files
        for file_name in "${include_files[@]}"; do
            file="$source_dir/$file_name"
            target_file="$target_dir/$file_name"

            if [[ ! -e "$file" ]]; then
                echo "  ! Warning: included file not found: $file_name"
                eval "skipped=\$(( \$skipped + 1 ))"
                continue
            fi

            if [[ "$dry_run" == "true" ]]; then
                local rel_src="${file#$dotconfigs_root/}"
                echo "  Would link $rel_src -> $target_file"
                eval "created=\$(( \$created + 1 ))"
            else
                # Call backup_and_link and capture status
                if backup_and_link "$file" "$target_file" "$file_name" "$interactive_mode"; then
                    # Successfully linked (output already printed by backup_and_link)
                    if is_dotconfigs_owned "$target_file" "$dotconfigs_root"; then
                        eval "updated=\$(( \$updated + 1 ))"
                    else
                        eval "created=\$(( \$created + 1 ))"
                    fi
                else
                    # Skipped (output already printed by backup_and_link)
                    eval "skipped=\$(( \$skipped + 1 ))"
                fi
            fi
        done

        # Clean up stale entries (include-list branch)
        cleanup_stale_in_directory "$target_dir" "$include_csv" "$dotconfigs_root" "$dry_run"
    else
        # Deploy all files in directory
        for file in "$source_dir"/*; do
            [[ ! -e "$file" ]] && continue
            [[ -d "$file" ]] && continue  # Skip subdirectories

            file_name=$(basename "$file")
            target_file="$target_dir/$file_name"

            if [[ "$dry_run" == "true" ]]; then
                local rel_src="${file#$dotconfigs_root/}"
                echo "  Would link $rel_src -> $target_file"
                eval "created=\$(( \$created + 1 ))"
            else
                # Call backup_and_link and capture status
                if backup_and_link "$file" "$target_file" "$file_name" "$interactive_mode"; then
                    # Successfully linked (output already printed by backup_and_link)
                    if is_dotconfigs_owned "$target_file" "$dotconfigs_root" 2>/dev/null; then
                        eval "updated=\$(( \$updated + 1 ))"
                    else
                        eval "created=\$(( \$created + 1 ))"
                    fi
                else
                    # Skipped (output already printed by backup_and_link)
                    eval "skipped=\$(( \$skipped + 1 ))"
                fi
            fi
        done

        # Build deployed CSV from all source files, then clean up stale entries
        local all_csv=""
        for file in "$source_dir"/*; do
            [[ ! -e "$file" ]] && continue
            [[ -d "$file" ]] && continue
            if [[ -n "$all_csv" ]]; then
                all_csv="$all_csv,$(basename "$file")"
            else
                all_csv="$(basename "$file")"
            fi
        done
        cleanup_stale_in_directory "$target_dir" "$all_csv" "$dotconfigs_root" "$dry_run"
    fi
}

# Deploy a single module (source -> target)
# Args: source, target, method, include_csv, dotconfigs_root, dry_run, interactive_mode
# Returns: status string via global counters
deploy_module() {
    local source="$1"
    local target="$2"
    local method="$3"
    local include_csv="$4"
    local dotconfigs_root="$5"
    local dry_run="$6"
    local interactive_mode="$7"
    local abs_source
    local abs_target
    local rel_src

    # Expand tilde in target
    abs_target=$(expand_tilde "$target")

    # Make source absolute if not already
    if [[ "$source" != /* ]]; then
        abs_source="$dotconfigs_root/$source"
    else
        abs_source="$source"
    fi

    # Compute relative source for display
    rel_src="${abs_source#$dotconfigs_root/}"

    # Validate source exists
    if [[ ! -e "$abs_source" ]]; then
        echo "  ! Warning: source not found: $rel_src"
        eval "skipped=\$(( \$skipped + 1 ))"
        return
    fi

    # Switch on method
    case "$method" in
        symlink)
            if [[ -d "$abs_source" ]]; then
                # Directory source: deploy files individually
                deploy_directory_files "$abs_source" "$abs_target" "$include_csv" "$dotconfigs_root" "$dry_run" "$interactive_mode"
            else
                # File source: single symlink
                if [[ "$dry_run" == "true" ]]; then
                    echo "  Would link $rel_src -> $abs_target"
                    eval "created=\$(( \$created + 1 ))"
                else
                    local file_name
                    file_name=$(basename "$abs_target")
                    if backup_and_link "$abs_source" "$abs_target" "$file_name" "$interactive_mode"; then
                        # Successfully linked (output already printed)
                        if is_dotconfigs_owned "$abs_target" "$dotconfigs_root" 2>/dev/null; then
                            eval "updated=\$(( \$updated + 1 ))"
                        else
                            eval "created=\$(( \$created + 1 ))"
                        fi
                    else
                        # Skipped
                        eval "skipped=\$(( \$skipped + 1 ))"
                    fi
                fi
            fi
            ;;
        copy)
            if [[ "$dry_run" == "true" ]]; then
                echo "  Would copy $rel_src -> $abs_target"
                eval "created=\$(( \$created + 1 ))"
            else
                local target_dir
                target_dir=$(dirname "$abs_target")
                mkdir -p "$target_dir"

                # Check if target already matches source
                if [[ -f "$abs_target" ]] && cmp -s "$abs_source" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                else
                    cp -p "$abs_source" "$abs_target"
                    echo "  ✓ Copied $rel_src -> $abs_target"
                    if [[ -f "$abs_target" ]]; then
                        eval "updated=\$(( \$updated + 1 ))"
                    else
                        eval "created=\$(( \$created + 1 ))"
                    fi
                fi
            fi
            ;;
        append)
            if [[ "$dry_run" == "true" ]]; then
                echo "  Would append $rel_src -> $abs_target"
                eval "created=\$(( \$created + 1 ))"
            else
                local target_dir
                target_dir=$(dirname "$abs_target")
                mkdir -p "$target_dir"

                # Check if content already present (idempotent)
                if [[ -f "$abs_target" ]] && grep -qF "$(cat "$abs_source")" "$abs_target"; then
                    echo "  Unchanged: $rel_src -> $abs_target (already present)"
                    eval "unchanged=\$(( \$unchanged + 1 ))"
                else
                    cat "$abs_source" >> "$abs_target"
                    echo "  ✓ Appended $rel_src -> $abs_target"
                    eval "updated=\$(( \$updated + 1 ))"
                fi
            fi
            ;;
        *)
            echo "  ! Warning: unknown method '$method' for $rel_src"
            eval "skipped=\$(( \$skipped + 1 ))"
            ;;
    esac
}

# Main deployment entry point
# Args: config_file, dotconfigs_root, [group_key], [dry_run], [force], [project_root]
deploy_from_json() {
    local config_file="$1"
    local dotconfigs_root="$2"
    local group_key="${3:-}"
    local dry_run="${4:-false}"
    local force="${5:-false}"
    local project_root="${6:-}"
    local interactive_mode
    local modules_data
    local line
    local source
    local target
    local method
    local include_csv

    # Check jq dependency
    if ! check_jq; then
        return 1
    fi

    # Validate config file exists
    if [[ ! -f "$config_file" ]]; then
        echo "Error: config file not found: $config_file"
        return 1
    fi

    # Determine interactive mode from force flag
    if [[ "$force" == "true" ]]; then
        interactive_mode="force"
    else
        interactive_mode="true"
    fi

    # Initialize counters (bash 3.2 compatible - no local -i)
    created=0
    updated=0
    unchanged=0
    skipped=0
    removed=0

    # Parse modules
    modules_data=$(parse_modules_in_group "$config_file" "$group_key")

    # Check if any modules found
    if [[ -z "$modules_data" ]]; then
        echo "No modules found in $config_file"
        if [[ -n "$group_key" ]]; then
            echo "(group: $group_key)"
        fi
        return 0
    fi

    # Print header
    if [[ "$dry_run" == "true" ]]; then
        echo "Dry-run mode: no changes will be made"
        echo ""
    fi

    if [[ -n "$group_key" ]]; then
        echo "Deploying group: $group_key"
    else
        echo "Deploying all modules"
    fi
    echo ""

    # Deploy each module
    while IFS=$'\t' read -r source target method include_csv; do
        # If project_root is set, resolve relative targets against it
        if [[ -n "$project_root" && "$target" != /* && "$target" != ~* ]]; then
            target="$project_root/$target"
        fi
        deploy_module "$source" "$target" "$method" "$include_csv" "$dotconfigs_root" "$dry_run" "$interactive_mode"
    done <<< "$modules_data"

    # Print summary
    echo ""
    echo "Deployment summary:"
    echo "  Created:   $created"
    echo "  Updated:   $updated"
    echo "  Unchanged: $unchanged"
    echo "  Removed:   $removed"
    echo "  Skipped:   $skipped"
}
