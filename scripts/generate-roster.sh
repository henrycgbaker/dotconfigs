#!/bin/bash
# Generate ROSTER.md from hook/command metadata
# Reads METADATA blocks from plugin files and builds comprehensive reference

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/docs/ROSTER.md"

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start building roster content
cat > "$OUTPUT_FILE" << 'HEADER'
# dotconfigs Hook & Command Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, commands, and configuration options in dotconfigs.

HEADER

# ============================================================================
# Git Hooks Section
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Git Hooks" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Git hooks run during git operations to enforce quality standards and protect workflows." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Hook | Description | Configuration Keys |" >> "$OUTPUT_FILE"
echo "|------|-------------|-------------------|" >> "$OUTPUT_FILE"

# Find all git hooks with metadata
while IFS= read -r hook_file; do
    if [[ -f "$hook_file" ]]; then
        # Extract metadata fields
        name=$(grep "^# NAME:" "$hook_file" | head -1 | sed 's/^# NAME: //')
        desc=$(grep "^# DESCRIPTION:" "$hook_file" | head -1 | sed 's/^# DESCRIPTION: //')
        config=$(grep "^# CONFIGURABLE:" "$hook_file" | head -1 | sed 's/^# CONFIGURABLE: //')

        if [[ -n "$name" ]]; then
            # Format config keys as comma-separated list
            config_display="${config//, /, }"
            echo "| $name | $desc | $config_display |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(find "$REPO_ROOT/plugins/git/hooks" -type f ! -name "*.md" | sort)

# ============================================================================
# Claude Hooks Section
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Claude Hooks" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Claude hooks run during Claude Code operations for code quality and safety." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Hook | Description | Configuration Keys |" >> "$OUTPUT_FILE"
echo "|------|-------------|-------------------|" >> "$OUTPUT_FILE"

# Find all claude hooks with metadata
while IFS= read -r hook_file; do
    if [[ -f "$hook_file" ]]; then
        # Extract metadata fields (works for both bash # and python # comments)
        name=$(grep "^# NAME:" "$hook_file" | head -1 | sed 's/^# NAME: //')
        desc=$(grep "^# DESCRIPTION:" "$hook_file" | head -1 | sed 's/^# DESCRIPTION: //')
        config=$(grep "^# CONFIGURABLE:" "$hook_file" | head -1 | sed 's/^# CONFIGURABLE: //')

        if [[ -n "$name" ]]; then
            config_display="${config//, /, }"
            echo "| $name | $desc | $config_display |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(find "$REPO_ROOT/plugins/claude/hooks" -type f ! -name "*.md" | sort)

# ============================================================================
# Commands Section
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Commands" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Custom Claude Code commands (skills) for common workflows." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Command | Description |" >> "$OUTPUT_FILE"
echo "|---------|-------------|" >> "$OUTPUT_FILE"

# Find all command .md files and extract description from frontmatter
while IFS= read -r cmd_file; do
    if [[ -f "$cmd_file" ]]; then
        # Extract command name from filename (remove .md extension)
        cmd_name=$(basename "$cmd_file" .md)

        # Extract description from YAML frontmatter (more robust awk)
        desc=$(awk '/^---$/ {p=1; next} p && /^---$/ {p=0} p && /^description:/ {sub(/^description: */, ""); print; exit}' "$cmd_file")

        if [[ -n "$desc" ]]; then
            echo "| /$cmd_name | $desc |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(find "$REPO_ROOT/plugins/claude/commands" -type f -name "*.md" | sort)

# ============================================================================
# Configuration Reference
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Configuration Reference" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "All hook configuration follows a three-tier hierarchy:" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "1. **Hardcoded defaults** — Built into hook code (documented below)" >> "$OUTPUT_FILE"
echo "2. **Environment variables** — Set in \`.env\` or shell environment" >> "$OUTPUT_FILE"
echo "3. **Project config files** — Per-repository overrides" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Higher tiers override lower tiers (config file > env var > default)." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Git Hook Configuration" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Variable | Default | Description |" >> "$OUTPUT_FILE"
echo "|----------|---------|-------------|" >> "$OUTPUT_FILE"

# Parse lib/config.sh for GIT_HOOK_* variable documentation
while IFS= read -r line; do
    if [[ "$line" =~ ^#\ GIT_HOOK_ ]]; then
        # Extract variable=default and description
        var_line=$(echo "$line" | sed 's/^# //')
        var_name=$(echo "$var_line" | cut -d= -f1)
        var_default=$(echo "$var_line" | cut -d= -f2 | awk '{print $1}')
        var_desc=$(echo "$var_line" | cut -d= -f2- | sed "s/^[^ ]* *//")

        # Escape pipe characters in description for markdown table
        var_desc="${var_desc//|/\\|}"

        echo "| \`$var_name\` | \`$var_default\` | $var_desc |" >> "$OUTPUT_FILE"
    fi
done < <(grep "^# GIT_HOOK_" "$REPO_ROOT/lib/config.sh")

echo "" >> "$OUTPUT_FILE"
echo "### Claude Hook Configuration" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Variable | Default | Description |" >> "$OUTPUT_FILE"
echo "|----------|---------|-------------|" >> "$OUTPUT_FILE"

# Parse lib/config.sh for CLAUDE_HOOK_* variable documentation
while IFS= read -r line; do
    if [[ "$line" =~ ^#\ CLAUDE_HOOK_ ]]; then
        var_line=$(echo "$line" | sed 's/^# //')
        var_name=$(echo "$var_line" | cut -d= -f1)
        var_default=$(echo "$var_line" | cut -d= -f2 | awk '{print $1}')
        var_desc=$(echo "$var_line" | cut -d= -f2- | sed "s/^[^ ]* *//")
        var_desc="${var_desc//|/\\|}"

        echo "| \`$var_name\` | \`$var_default\` | $var_desc |" >> "$OUTPUT_FILE"
    fi
done < <(grep "^# CLAUDE_HOOK_" "$REPO_ROOT/lib/config.sh")

# ============================================================================
# Config File Locations
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "### Configuration File Locations" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "**Git hooks:** Per-project config files (first found wins):" >> "$OUTPUT_FILE"
echo "- \`.githooks/config\`" >> "$OUTPUT_FILE"
echo "- \`.claude/git-hooks.conf\`" >> "$OUTPUT_FILE"
echo "- \`.git/hooks/hooks.conf\`" >> "$OUTPUT_FILE"
echo "- \`.claude/hooks.conf\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "**Claude hooks:** Per-project config files (first found wins):" >> "$OUTPUT_FILE"
echo "- \`.claude/claude-hooks.conf\` (project-specific)" >> "$OUTPUT_FILE"
echo "- \`~/.claude/claude-hooks.conf\` (global fallback)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "### Plugin Configuration Ownership" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "- **Git plugin** owns \`git-hooks.conf\` — deployed by \`dotconfigs project git\`" >> "$OUTPUT_FILE"
echo "- **Claude plugin** owns \`claude-hooks.conf\` — deployed by \`dotconfigs project claude\`" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Footer
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*" >> "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
