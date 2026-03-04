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
# Customisation Section
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Customisation" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Hooks are opinionated by default. To add per-project behaviour, use \`.local\` extension scripts:" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "- \`.git/hooks/pre-commit.local\` — runs at end of pre-commit" >> "$OUTPUT_FILE"
echo "- \`.git/hooks/pre-push.local\` — runs at end of pre-push" >> "$OUTPUT_FILE"
echo "- \`.git/hooks/commit-msg.local\` — runs at end of commit-msg" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "To skip a hook entirely, exclude it in \`.dotconfigs/project.json\` before deploying." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Footer
echo "---" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*" >> "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
