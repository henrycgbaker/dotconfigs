# lib/validation.sh — Common validation helpers

# Validate that a path exists
# Args: path, purpose (defaults to "path")
# Returns: 0 if exists, 1 otherwise (with error message)
validate_path() {
    local path="$1"
    local purpose="${2:-path}"

    if [[ ! -e "$path" ]]; then
        echo "Error: $purpose does not exist: $path" >&2
        return 1
    fi

    return 0
}

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

# Expand tilde in path to $HOME
# Args: path
# Returns: Expanded path (via echo)
expand_path() {
    local path="$1"

    echo "${path/#\~/$HOME}"
}
