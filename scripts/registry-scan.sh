#!/bin/bash
# scripts/registry-scan.sh — Registry scanner for Claude Code configurations
# Catalogues agents, skills, hooks, and settings across projects.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTCLAUDE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Source symlink library for ownership detection
# shellcheck source=../lib/symlinks.sh
source "$DOTCLAUDE_ROOT/lib/symlinks.sh"

# Usage
show_usage() {
    cat <<EOF
Usage: registry-scan.sh [OPTIONS]

Scan projects for Claude Code configurations.

OPTIONS:
    --json      Output machine-readable JSON
    --help      Show this help

CONFIGURATION:
    Reads SCAN_PATHS from .env (comma-separated directories to scan)
    Example: SCAN_PATHS="~/Repositories,~/Projects"

OUTPUT:
    Default: Human-readable table showing sync status
    --json:  Machine-readable JSON with full details
EOF
}

# Parse arguments
OUTPUT_FORMAT="table"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --json)
            OUTPUT_FORMAT="json"
            shift
            ;;
        --help|-h)
            show_usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Load environment
if [[ ! -f "$DOTCLAUDE_ROOT/.env" ]]; then
    echo "Error: No .env file found"
    echo ""
    echo "Run 'dotconfigs setup claude' to configure, or manually create .env with SCAN_PATHS."
    echo "Example: SCAN_PATHS=\"$HOME/Repositories,$HOME/Projects\""
    exit 1
fi

# shellcheck source=/dev/null
source "$DOTCLAUDE_ROOT/.env"

if [[ -z "${SCAN_PATHS:-}" ]]; then
    echo "Error: SCAN_PATHS not configured in .env"
    echo ""
    echo "Run 'dotconfigs setup claude' to configure, or set SCAN_PATHS in .env:"
    echo "  SCAN_PATHS=\"$HOME/Repositories,$HOME/Projects\""
    exit 1
fi

# Expand tilde in paths
expand_path() {
    local path="$1"
    # Replace leading tilde with HOME
    path="${path/#\~/$HOME}"
    echo "$path"
}

# Check file status (synced/custom/missing)
check_file_status() {
    local project_path="$1"
    local file_path="$2"

    if [[ ! -e "$file_path" && ! -L "$file_path" ]]; then
        echo "missing"
        return
    fi

    if is_dotclaude_owned "$file_path" "$DOTCLAUDE_ROOT"; then
        echo "synced"
    else
        echo "custom"
    fi
}

# Parse hooks.conf for profile
parse_hooks_profile() {
    local hooks_conf="$1"

    if [[ ! -f "$hooks_conf" ]]; then
        echo "missing"
        return
    fi

    # Extract HOOK_PROFILE value
    local profile
    profile=$(grep -E "^HOOK_PROFILE=" "$hooks_conf" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")

    if [[ -z "$profile" ]]; then
        echo "unknown"
    else
        echo "$profile"
    fi
}

# Count items in directory
count_items() {
    local dir="$1"

    if [[ ! -d "$dir" ]]; then
        echo "0"
        return
    fi

    # Count files (not directories)
    find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' '
}

# Scan a single project
scan_project() {
    local project_path="$1"
    local settings_status claude_md_status hooks_profile skills_count agents_count

    # Check settings.json
    settings_status=$(check_file_status "$project_path" "$project_path/.claude/settings.json")

    # Check CLAUDE.md
    claude_md_status=$(check_file_status "$project_path" "$project_path/CLAUDE.md")

    # Check hooks.conf
    hooks_profile=$(parse_hooks_profile "$project_path/.claude/hooks.conf")

    # Count skills
    skills_count=$(count_items "$project_path/.claude/commands")

    # Count agents
    agents_count=$(count_items "$project_path/.claude/agents")

    # Determine overall status
    local status="OK"
    if [[ "$settings_status" == "missing" && "$claude_md_status" == "missing" ]]; then
        status="Unmanaged"
    elif [[ "$settings_status" == "custom" || "$claude_md_status" == "custom" ]]; then
        status="Custom"
    fi

    # Output as JSON object (will be collected by main scan)
    cat <<EOF
{
    "path": "$project_path",
    "settings": {"status": "$settings_status"},
    "claude_md": {"status": "$claude_md_status"},
    "hooks_conf": {"profile": "$hooks_profile"},
    "skills": $skills_count,
    "agents": $agents_count,
    "status": "$status"
}
EOF
}

# Find all projects with .claude/ directories
find_projects() {
    local scan_path="$1"

    # Expand tilde
    scan_path=$(expand_path "$scan_path")

    if [[ ! -d "$scan_path" ]]; then
        return
    fi

    # Find directories containing .claude/ subdirectory
    # Use maxdepth 3 to avoid deep recursion
    find "$scan_path" -maxdepth 3 -type d -name ".claude" 2>/dev/null | while read -r claude_dir; do
        # Get parent directory (the project root)
        dirname "$claude_dir"
    done
}

# Main scan
scan_all_projects() {
    local projects=()
    local project_data=()

    # Split SCAN_PATHS on comma and scan each
    IFS=',' read -ra paths <<< "$SCAN_PATHS"
    for path in "${paths[@]}"; do
        # Trim whitespace
        path=$(echo "$path" | xargs)

        # Find projects in this path
        while IFS= read -r project; do
            projects+=("$project")
        done < <(find_projects "$path")
    done

    # Scan each project
    for project in "${projects[@]}"; do
        project_data+=("$(scan_project "$project")")
    done

    # Output based on format
    if [[ "$OUTPUT_FORMAT" == "json" ]]; then
        # JSON output
        echo "{"
        echo "  \"scan_date\": \"$(date -u +"%Y-%m-%d")\","
        echo "  \"scan_paths\": ["
        IFS=',' read -ra paths <<< "$SCAN_PATHS"
        local first=true
        for path in "${paths[@]}"; do
            path=$(echo "$path" | xargs)
            path=$(expand_path "$path")
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo -n "    \"$path\""
        done
        echo ""
        echo "  ],"
        echo "  \"projects\": ["

        local first=true
        for data in "${project_data[@]}"; do
            if [[ "$first" == "true" ]]; then
                first=false
            else
                echo ","
            fi
            echo "    $data"
        done

        echo ""
        echo "  ]"
        echo "}"
    else
        # Table output
        echo ""
        echo "Registry Scan — ${#projects[@]} projects found"
        echo ""
        printf "%-40s %-10s %-12s %-12s %-8s %-10s\n" "Project" "Settings" "CLAUDE.md" "Hooks" "Skills" "Status"
        echo "────────────────────────────────────────────────────────────────────────────────────────"

        for i in "${!projects[@]}"; do
            local project="${projects[$i]}"
            local data="${project_data[$i]}"

            # Parse JSON data
            local settings=$(echo "$data" | grep -o '"settings".*"status"[^"]*"[^"]*"' | sed 's/.*: "\([^"]*\)".*/\1/')
            local claude_md=$(echo "$data" | grep -o '"claude_md".*"status"[^"]*"[^"]*"' | sed 's/.*: "\([^"]*\)".*/\1/')
            local hooks=$(echo "$data" | grep -o '"profile"[^"]*"[^"]*"' | sed 's/.*: "\([^"]*\)".*/\1/')
            local skills=$(echo "$data" | grep -o '"skills": [0-9]*' | sed 's/.*: //')
            local status=$(echo "$data" | grep -o '"status"[^"]*"[^"]*"' | tail -1 | sed 's/.*: "\([^"]*\)".*/\1/')

            # Shorten project path (replace HOME with ~)
            local short_path="${project/#$HOME/\~}"

            printf "%-40s %-10s %-12s %-12s %-8s %-10s\n" \
                "$short_path" "$settings" "$claude_md" "$hooks" "$skills" "$status"
        done

        echo ""
    fi
}

# Run scan
scan_all_projects
