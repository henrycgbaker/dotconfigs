#!/bin/bash
# Generate ROSTER.md from the plugin catalogues (manifest.json).
#
# SSOT chain: plugins/*/manifest.json → this script → docs/ROSTER.md
# - Hooks: name + description + event/matcher (from each hook's `wiring`).
# - Skills: name (from manifest) + description (from each SKILL.md frontmatter).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_FILE="$REPO_ROOT/docs/ROSTER.md"

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to parse manifests" >&2
    exit 1
fi

mkdir -p "$(dirname "$OUTPUT_FILE")"

cat > "$OUTPUT_FILE" << 'HEADER'
# dotconfigs Hook & Skill Roster

**Auto-generated reference** — Do not edit manually. Run `scripts/generate-roster.sh` to regenerate.

This document lists the hooks and skills catalogued in dotconfigs. Toggle any item on or
off in your `deploy.json` (`~/.dotconfigs/deploy.json` for the machine, or
`<repo>/.dotconfigs/deploy.json` for a project).

HEADER

# Append a "## <heading>" table of a plugin's hooks, sourced from the `hooks`
# category of its manifest.json (name, description, and event/matcher wiring).
# Args: plugin, heading, intro
emit_hook_table() {
    local plugin="$1" heading="$2" intro="$3"
    local manifest="$REPO_ROOT/plugins/$plugin/manifest.json"

    {
        echo ""
        echo "## $heading"
        echo ""
        echo "$intro"
        echo ""
        echo "| Hook | Description | Event / Matcher |"
        echo "|------|-------------|-----------------|"
    } >> "$OUTPUT_FILE"

    jq -r '
        (.hooks // {}) | to_entries[]
        | .key as $name | .value as $e
        | ($e.description // "") as $desc
        | ( ($e.wiring // [] | if type == "array" then . else [.] end)
            | map(.event + (if .matcher then " (" + .matcher + ")" else "" end))
            | join(", ") ) as $wiring
        | "| \($name) | \($desc) | \($wiring) |"
    ' "$manifest" >> "$OUTPUT_FILE"
}

emit_hook_table git "Git Hooks" "Git hooks run during git operations to enforce quality standards and protect workflows."
emit_hook_table claude "Claude Hooks" "Claude hooks run during Claude Code operations for code quality and safety."

CLAUDE_MANIFEST="$REPO_ROOT/plugins/claude/manifest.json"

# ============================================================================
# Skills — names from the manifest, descriptions from each SKILL.md frontmatter
# ============================================================================

{
    echo ""
    echo "## Skills"
    echo ""
    echo "Custom Claude Code skills (\`/name\`) for common workflows."
    echo ""
    echo "| Command | Description |"
    echo "|---------|-------------|"
} >> "$OUTPUT_FILE"

while IFS= read -r skill_name; do
    skill_file="$REPO_ROOT/plugins/claude/skills/$skill_name/SKILL.md"
    if [[ -f "$skill_file" ]]; then
        desc=$(awk '/^---$/ {p=1; next} p && /^---$/ {p=0} p && /^description:/ {sub(/^description: */, ""); print; exit}' "$skill_file")
        if [[ -n "$desc" ]]; then
            echo "| /$skill_name | $desc |" >> "$OUTPUT_FILE"
        fi
    fi
done < <(jq -r '(.skills // {}) | keys[]' "$CLAUDE_MANIFEST")

# ============================================================================
# Customisation
# ============================================================================

{
    echo ""
    echo "## Customisation"
    echo ""
    echo "Hooks are opinionated and on by default. To disable one, set it \`false\` in your"
    echo "\`deploy.json\` and re-run \`dotconfigs deploy\` — the hook is then neither symlinked"
    echo "nor wired into settings.json."
    echo ""
    echo "For per-project additions without editing the shared hook, use \`.local\` scripts:"
    echo ""
    echo "- \`.git/hooks/pre-commit.local\` — runs at end of pre-commit"
    echo "- \`.git/hooks/pre-push.local\` — runs at end of pre-push"
    echo "- \`.git/hooks/commit-msg.local\` — runs at end of commit-msg"
    echo ""
    echo "---"
    echo ""
    echo "*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*"
} >> "$OUTPUT_FILE"

echo "✓ Generated: $OUTPUT_FILE"
