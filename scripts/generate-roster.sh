#!/bin/bash
# Generate ROSTER.md from plugin manifests and hook METADATA
#
# SSOT chain: manifests → hook files → this script → ROSTER.md
# - Discovers hooks/commands via manifest.json (not filesystem find)
# - Reads descriptions and config from hook METADATA blocks (# CONFIG: lines)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/docs/ROSTER.md"

# Ensure jq is available (manifests are JSON)
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to parse manifests" >&2
    exit 1
fi

# Ensure output directory exists
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Start building roster content
cat > "$OUTPUT_FILE" << 'HEADER'
# dotconfigs Hook & Command Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, commands, and configuration options in dotconfigs.

HEADER

# ============================================================================
# Git Hooks Section — discovered via plugins/git/manifest.json
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Git Hooks" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Git hooks run during git operations to enforce quality standards and protect workflows." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Hook | Description | Configuration Keys |" >> "$OUTPUT_FILE"
echo "|------|-------------|-------------------|" >> "$OUTPUT_FILE"

GIT_MANIFEST="$REPO_ROOT/plugins/git/manifest.json"

while IFS= read -r hook_name; do
    hook_file="$REPO_ROOT/plugins/git/hooks/$hook_name"
    if [[ -f "$hook_file" ]]; then
        name=$(grep "^# NAME:" "$hook_file" | head -1 | sed 's/^# NAME: //')
        desc=$(grep "^# DESCRIPTION:" "$hook_file" | head -1 | sed 's/^# DESCRIPTION: //')

        # Extract config key names from CONFIG lines
        config=$(grep "^# CONFIG:" "$hook_file" 2>/dev/null | sed 's/^# CONFIG: //' | cut -d= -f1 | paste -sd',' - | sed 's/,/, /g' || true)

        if [[ -n "$name" ]]; then
            echo "| $name | $desc | $config |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(jq -r '.global.hooks.include[]' "$GIT_MANIFEST" | sort)

# ============================================================================
# Claude Hooks Section — discovered via plugins/claude/manifest.json
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Claude Hooks" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Claude hooks run during Claude Code operations for code quality and safety." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Hook | Description | Configuration Keys |" >> "$OUTPUT_FILE"
echo "|------|-------------|-------------------|" >> "$OUTPUT_FILE"

CLAUDE_MANIFEST="$REPO_ROOT/plugins/claude/manifest.json"

while IFS= read -r hook_name; do
    hook_file="$REPO_ROOT/plugins/claude/hooks/$hook_name"
    if [[ -f "$hook_file" ]]; then
        name=$(grep "^# NAME:" "$hook_file" | head -1 | sed 's/^# NAME: //')
        desc=$(grep "^# DESCRIPTION:" "$hook_file" | head -1 | sed 's/^# DESCRIPTION: //')

        # Extract config key names from CONFIG lines
        config=$(grep "^# CONFIG:" "$hook_file" 2>/dev/null | sed 's/^# CONFIG: //' | cut -d= -f1 | paste -sd',' - | sed 's/,/, /g' || true)

        if [[ -n "$name" ]]; then
            echo "| $name | $desc | $config |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(jq -r '.global.hooks.include[]' "$CLAUDE_MANIFEST" | sort)

# ============================================================================
# Commands Section — discovered via plugins/claude/manifest.json
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Commands" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Custom Claude Code commands (skills) for common workflows." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Command | Description |" >> "$OUTPUT_FILE"
echo "|---------|-------------|" >> "$OUTPUT_FILE"

while IFS= read -r cmd_file_name; do
    cmd_file="$REPO_ROOT/plugins/claude/commands/$cmd_file_name"
    if [[ -f "$cmd_file" ]]; then
        # Extract command name from filename (remove .md extension)
        cmd_name=$(basename "$cmd_file" .md)

        # Extract description from YAML frontmatter
        desc=$(awk '/^---$/ {p=1; next} p && /^---$/ {p=0} p && /^description:/ {sub(/^description: */, ""); print; exit}' "$cmd_file")

        if [[ -n "$desc" ]]; then
            echo "| /$cmd_name | $desc |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(jq -r '.global.skills.include[]' "$CLAUDE_MANIFEST" | sort)

# ============================================================================
# Configuration Reference — parsed from hook CONFIG lines (not lib/config.sh)
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

# Collect CONFIG lines from all git hooks declared in manifest, deduplicate
{
    while IFS= read -r hook_name; do
        hook_file="$REPO_ROOT/plugins/git/hooks/$hook_name"
        if [[ -f "$hook_file" ]]; then
            grep "^# CONFIG:" "$hook_file" 2>/dev/null || true
        fi
    done < <(jq -r '.global.hooks.include[]' "$GIT_MANIFEST")
} | sort -u | while IFS= read -r line; do
    if [[ -z "$line" ]]; then continue; fi
    # Parse: # CONFIG: VAR_NAME=default  Description
    config_def=$(echo "$line" | sed 's/^# CONFIG: //')
    var_name=$(echo "$config_def" | cut -d= -f1)
    rest=$(echo "$config_def" | cut -d= -f2-)
    var_default=$(echo "$rest" | awk '{print $1}')
    var_desc=$(echo "$rest" | sed "s/^[^ ]* *//" )
    var_desc="${var_desc//|/\\|}"

    echo "| \`$var_name\` | \`$var_default\` | $var_desc |" >> "$OUTPUT_FILE"
done

echo "" >> "$OUTPUT_FILE"
echo "### Claude Hook Configuration" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Variable | Default | Description |" >> "$OUTPUT_FILE"
echo "|----------|---------|-------------|" >> "$OUTPUT_FILE"

# Collect CONFIG lines from all claude hooks declared in manifest
{
    while IFS= read -r hook_name; do
        hook_file="$REPO_ROOT/plugins/claude/hooks/$hook_name"
        if [[ -f "$hook_file" ]]; then
            grep "^# CONFIG:" "$hook_file" 2>/dev/null || true
        fi
    done < <(jq -r '.global.hooks.include[]' "$CLAUDE_MANIFEST")
} | sort -u | while IFS= read -r line; do
    if [[ -z "$line" ]]; then continue; fi
    config_def=$(echo "$line" | sed 's/^# CONFIG: //')
    var_name=$(echo "$config_def" | cut -d= -f1)
    rest=$(echo "$config_def" | cut -d= -f2-)
    var_default=$(echo "$rest" | awk '{print $1}')
    var_desc=$(echo "$rest" | sed "s/^[^ ]* *//" )
    var_desc="${var_desc//|/\\|}"

    echo "| \`$var_name\` | \`$var_default\` | $var_desc |" >> "$OUTPUT_FILE"
done

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
