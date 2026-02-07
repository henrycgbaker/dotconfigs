#!/bin/bash
# scripts/lib/discovery.sh — Dynamic scanning of dotclaude repo contents
# Sourced by deploy.sh. Do not execute directly.

# Find available Claude Code hooks in hooks/ directory
# Args: dotclaude_root
# Returns: List of hook filenames (one per line)
discover_hooks() {
    local dotclaude_root="$1"
    local hooks_dir="$dotclaude_root/hooks"

    if [[ ! -d "$hooks_dir" ]]; then
        return 0
    fi

    find "$hooks_dir" -type f -name "*.py" -o -name "*.sh" | while read -r hook_path; do
        basename "$hook_path"
    done | sort
}

# Find available git hooks in githooks/ directory
# Args: dotclaude_root
# Returns: List of hook filenames (one per line)
discover_githooks() {
    local dotclaude_root="$1"
    local githooks_dir="$dotclaude_root/githooks"

    if [[ ! -d "$githooks_dir" ]]; then
        return 0
    fi

    find "$githooks_dir" -type f ! -name "*.md" ! -name ".*" | while read -r hook_path; do
        basename "$hook_path"
    done | sort
}

# Find available skills in commands/ directory
# Args: dotclaude_root
# Returns: List of skill names without .md extension (one per line)
discover_skills() {
    local dotclaude_root="$1"
    local commands_dir="$dotclaude_root/commands"

    if [[ ! -d "$commands_dir" ]]; then
        return 0
    fi

    find "$commands_dir" -type f -name "*.md" | while read -r skill_path; do
        local filename
        filename=$(basename "$skill_path")
        echo "${filename%.md}"
    done | sort
}

# Find available CLAUDE.md section templates
# Args: dotclaude_root
# Returns: List of section names (extracted from filename, one per line)
discover_claude_sections() {
    local dotclaude_root="$1"
    local templates_dir="$dotclaude_root/templates/claude-md"

    if [[ ! -d "$templates_dir" ]]; then
        return 0
    fi

    find "$templates_dir" -type f -name "*.md" | while read -r template_path; do
        local filename section_name
        filename=$(basename "$template_path")
        # Extract section name: "01-communication.md" → "communication"
        section_name=$(echo "$filename" | sed -E 's/^[0-9]+-(.*)\.md$/\1/')
        echo "$section_name"
    done | sort
}

# Find available settings templates
# Args: dotclaude_root
# Returns: List of template names (one per line)
discover_settings_templates() {
    local dotclaude_root="$1"
    local templates_dir="$dotclaude_root/templates/settings"

    if [[ ! -d "$templates_dir" ]]; then
        return 0
    fi

    find "$templates_dir" -type f -name "*.json" | while read -r template_path; do
        local filename
        filename=$(basename "$template_path")
        echo "${filename%.json}"
    done | sort
}
