#!/bin/bash
# scripts/lib/symlinks.sh — Symlink management and ownership detection
# Sourced by deploy.sh. Do not execute directly.

# Check if a file is a symlink pointing to the dotclaude repo
# Args: target_path, dotclaude_path
# Returns: 0 if owned by dotclaude, 1 otherwise
is_dotclaude_owned() {
    local target_path="$1"
    local dotclaude_path="$2"
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

    # Check if link target starts with dotclaude path
    if [[ "$link_target" == "$dotclaude_path"* ]]; then
        return 0
    fi

    return 1
}

# Create a symlink with conflict handling
# Args: src, dest, name, interactive (true/false)
backup_and_link() {
    local src="$1"
    local dest="$2"
    local name="$3"
    local interactive="$4"
    local dotclaude_root

    # Extract dotclaude root from src path (everything before /commands, /hooks, etc)
    dotclaude_root=$(echo "$src" | sed -E 's|(.*)/[^/]+/[^/]+$|\1|')

    # If dest doesn't exist, create symlink
    if [[ ! -e "$dest" && ! -L "$dest" ]]; then
        link_file "$src" "$dest"
        echo "  ✓ Linked $name"
        return 0
    fi

    # If dest exists and is owned by dotclaude, overwrite silently
    if is_dotclaude_owned "$dest" "$dotclaude_root"; then
        link_file "$src" "$dest"
        echo "  ✓ Updated $name"
        return 0
    fi

    # Dest exists and NOT owned by dotclaude
    if [[ "$interactive" == "true" ]]; then
        echo "  ! Conflict: $name already exists and not managed by dotclaude"
        echo "    Current: $dest"
        echo "    Options: [o]verwrite, [s]kip, [b]ackup"
        read -p "    Choice: " choice
        choice=$(echo "$choice" | tr '[:upper:]' '[:lower:]')
        case "$choice" in
            o|overwrite)
                link_file "$src" "$dest"
                echo "  ✓ Overwrote $name"
                return 0
                ;;
            b|backup)
                local backup="${dest}.backup.$(date +%Y%m%d-%H%M%S)"
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
