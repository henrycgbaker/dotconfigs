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
# dotconfigs Hook & Skill Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists all available hooks, skills, and configuration options in dotconfigs.

HEADER

# ============================================================================
# Hook Sections — discovered via each plugin's manifest.json
# ============================================================================

# Append a "## <heading>" table of a plugin's hooks. NAME/DESCRIPTION/CONFIG
# are read from each hook file's METADATA block (missing fields tolerated).
# Args: plugin, heading, intro
emit_hook_table() {
    local plugin="$1" heading="$2" intro="$3"
    local manifest="$REPO_ROOT/plugins/$plugin/manifest.json"
    local hook_name hook_file name desc config

    {
        echo ""
        echo "## $heading"
        echo ""
        echo "$intro"
        echo ""
        echo "| Hook | Description | Configuration Keys |"
        echo "|------|-------------|-------------------|"
    } >> "$OUTPUT_FILE"

    while IFS= read -r hook_name; do
        hook_file="$REPO_ROOT/plugins/$plugin/hooks/$hook_name"
        [[ -f "$hook_file" ]] || continue
        name=$(grep "^# NAME:" "$hook_file" | head -1 | sed 's/^# NAME: //' || true)
        desc=$(grep "^# DESCRIPTION:" "$hook_file" | head -1 | sed 's/^# DESCRIPTION: //' || true)
        config=$(grep "^# CONFIG:" "$hook_file" 2>/dev/null | sed 's/^# CONFIG: //' | cut -d= -f1 | paste -sd',' - | sed 's/,/, /g' || true)
        if [[ -n "$name" ]]; then
            echo "| $name | $desc | $config |" >> "$OUTPUT_FILE"
        fi
    done < <(jq -r '.global.hooks.include[]' "$manifest" | sort)
}

emit_hook_table git "Git Hooks" "Git hooks run during git operations to enforce quality standards and protect workflows."
emit_hook_table claude "Claude Hooks" "Claude hooks run during Claude Code operations for code quality and safety."

# Reused by the Skills section below.
CLAUDE_MANIFEST="$REPO_ROOT/plugins/claude/manifest.json"

# ============================================================================
# Commands Section — discovered via plugins/claude/manifest.json
# ============================================================================

echo "" >> "$OUTPUT_FILE"
echo "## Skills" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "Custom Claude Code skills (\`/name\`) for common workflows." >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "| Command | Description |" >> "$OUTPUT_FILE"
echo "|---------|-------------|" >> "$OUTPUT_FILE"

while IFS= read -r skill_name; do
    skill_file="$REPO_ROOT/plugins/claude/skills/$skill_name/SKILL.md"
    if [[ -f "$skill_file" ]]; then
        # Extract description from YAML frontmatter
        desc=$(awk '/^---$/ {p=1; next} p && /^---$/ {p=0} p && /^description:/ {sub(/^description: */, ""); print; exit}' "$skill_file")

        if [[ -n "$desc" ]]; then
            echo "| /$skill_name | $desc |" >> "$OUTPUT_FILE"
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
