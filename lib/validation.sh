# lib/validation.sh — Common validation helpers

# Check if a directory is a git repository
# Args: path (defaults to ".")
# Returns: 0 if git repo, 1 otherwise
is_git_repo() {
    local path="${1:-.}"

    [[ -d "$path/.git" ]]
}

# Validate that a directory is a git repository
# Args: path (defaults to ".")
# Returns: 0 if git repo, 1 otherwise (with error message)
validate_git_repo() {
    local path="${1:-.}"

    if ! is_git_repo "$path"; then
        echo "Error: Not a git repository: $path" >&2
        echo "  Suggestion: cd $path && git init" >&2
        return 1
    fi

    return 0
}
