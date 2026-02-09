# lib/symlinks.sh — Symlink management and ownership detection
# Sourced by dotconfigs entry point.

# Check if a file is a symlink pointing to the dotconfigs repo
# Args: target_path, dotconfigs_path
# Returns: 0 if owned by dotconfigs, 1 otherwise
is_dotconfigs_owned() {
    local target_path="$1"
    local dotconfigs_path="$2"
    local link_target

    # Check if target is a symlink
    if [[ ! -L "$target_path" ]]; then
        return 1
    fi

    # Get link target with platform-specific handling
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: readlink doesn't have -f, use perl
        link_target=$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null)
    else
        # Linux: use readlink -f
        link_target=$(readlink -f "$target_path" 2>/dev/null)
    fi

    # Check if link target starts with dotconfigs path
    if [[ "$link_target" == "$dotconfigs_path"* ]]; then
        return 0
    fi

    return 1
}

# Check file deployment state for status reporting
# Args: target_path, expected_source, dotconfigs_root
# Returns: State string via stdout. Always returns 0 (safe with set -e).
check_file_state() {
    local target_path="$1"
    local expected_source="$2"
    local dotconfigs_root="$3"
    local link_target

    # Case 1: Target doesn't exist (and isn't a dangling symlink)
    if [[ ! -e "$target_path" && ! -L "$target_path" ]]; then
        echo "not-deployed"
        return 0
    fi

    # Case 2: Target is a symlink but broken (dangling)
    if [[ -L "$target_path" && ! -e "$target_path" ]]; then
        echo "drifted-broken"
        return 0
    fi

    # Case 3: Target is a symlink and owned by dotconfigs
    if [[ -L "$target_path" ]] && is_dotconfigs_owned "$target_path" "$dotconfigs_root"; then
        # Resolve absolute path with platform-specific handling
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS: readlink doesn't have -f, use perl
            link_target=$(perl -MCwd -le 'print Cwd::abs_path(shift)' "$target_path" 2>/dev/null)
        else
            # Linux: use readlink -f
            link_target=$(readlink -f "$target_path" 2>/dev/null)
        fi

        # Compare resolved path to expected source
        if [[ "$link_target" == "$expected_source" ]]; then
            echo "deployed"
        else
            echo "drifted-wrong-target"
        fi
        return 0
    fi

    # Case 4: Target is a symlink but NOT owned by dotconfigs
    if [[ -L "$target_path" ]]; then
        echo "drifted-foreign"
        return 0
    fi

    # Case 5: Target is a regular file (not a symlink)
    if [[ -f "$target_path" ]]; then
        echo "drifted-foreign"
        return 0
    fi

    # Fallback: Unknown state
    echo "not-deployed"
    return 0
}

# Create a symlink with conflict handling
# Args: src, dest, name, interactive_mode (true/false/force)
backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local interactive_mode="$4"
    local dotconfigs_root

    # Extract dotconfigs root from src path (everything before /commands, /hooks, etc)
    dotconfigs_root=$(echo "$src" | sed -E 's|(.*)/[^/]+/[^/]+$|\1|')

    # If dest doesn't exist, create symlink
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        link_file "$src" "$dest"
        echo "  ✓ Linked $name"
        return 0
    fi

    # If dest exists and is owned by dotconfigs, overwrite silently
    if is_dotconfigs_owned "$dest" "$dotconfigs_root"; then
        link_file "$src" "$dest"
        echo "  ✓ Updated $name"
        return 0
    fi

    # Dest exists and NOT owned by dotconfigs
    if [[ "$interactive_mode" == "force" ]]; then
        # Force mode: overwrite without prompting
        link_file "$src" "$dest"
        echo "  ✓ Overwrote $name (forced)"
        return 0
    elif [[ "$interactive_mode" == "true" ]]; then
        # Interactive mode: prompt with diff option
        while true; do
            echo "  ! Conflict: $name already exists and not managed by dotconfigs"
            echo "    Current: $dest"
            echo "    Options: [o]verwrite, [s]kip, [b]ackup, [d]iff"
            read -p "    Choice: " choice
            choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
            case "$choice" in
                d|diff)
                    # Show diff if dest is a regular file
                    if [[ -f "$dest" && ! -L "$dest" ]]; then
                        echo ""
                        diff "$src" "$dest" || true
                        echo ""
                    else
                        echo "  Cannot diff: target is not a regular file"
                        echo ""
                    fi
                    # Re-prompt without diff option
                    continue
                    ;;
                o|overwrite)
                    link_file "$src" "$dest"
                    echo "  ✓ Overwrote $name"
                    return 0
                    ;;
                b|backup)
                    local backup="${dest}.bak.$(date +%Y%m%d-%H%M%S)"
                    mv "$dest" "$backup"
                    link_file "$src" "$dest"
                    echo "  ✓ Backed up to $backup and linked $name"
                    return 0
                    ;;
                s|skip|*)
                    echo "  - Skipped $name"
                    return 1
                    ;;
            esac
        done
    else
        # Non-interactive mode: skip conflicts
        echo "  - Skipped $name (already exists, not managed)"
        return 1
    fi
}

# Simple symlink creation wrapper
# Args: src, dest
link_file() {
    local src="$1"
    local dest="$2"
    local dest_dir

    dest_dir=$(dirname "$dest")

    # Create parent directory if needed
    if [[ ! -d "$dest_dir" ]]; then
        mkdir -p "$dest_dir"
    fi

    # Create symlink (force overwrite if exists)
    ln -sfn "$src" "$dest"
}
