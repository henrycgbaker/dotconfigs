#!/usr/bin/env bash
# Build the native Claude Code plugin into top-level claude-plugin/.
#
# Generates an installable Claude Code plugin FROM the dotconfigs plugin source
# at plugins/claude/ (hooks, skills, output-styles, settings.json). The output
# is committed so installers needn't run this build.
#
# What it produces under claude-plugin/:
#   .claude-plugin/plugin.json  — generated manifest (name/version/desc/author)
#   hooks/hooks.json            — generated from plugins/claude/settings.json .hooks,
#                                 with commands repointed at ${CLAUDE_PLUGIN_ROOT}
#   hooks/*.sh                  — relative symlinks back to plugins/claude/hooks/*.sh
#   skills/                     — relative symlink to ../plugins/claude/skills
#   output-styles/              — relative symlink to ../plugins/claude/output-styles
#   settings.json               — non-hook portion of plugins/claude/settings.json
#
# Idempotent: the generated claude-plugin/ tree is removed and rebuilt each run.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

SRC="$REPO_ROOT/plugins/claude"
SETTINGS_SRC="$SRC/settings.json"
OUT="$REPO_ROOT/claude-plugin"

# Plugin identity. No version source exists in the repo today, so default 0.1.0.
PLUGIN_NAME="dots"
PLUGIN_VERSION="0.1.0"
PLUGIN_DESCRIPTION="Henry Baker's Claude Code config: safety hooks, git workflow skills, and a concise-execution output style."

# jq is required for all JSON parsing/generation.
if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to build the plugin" >&2
    exit 1
fi

if [[ ! -f "$SETTINGS_SRC" ]]; then
    echo "ERROR: missing plugin source settings: $SETTINGS_SRC" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Author attribution — mirror lib/deploy.sh _substitute_placeholders fallbacks.
# ---------------------------------------------------------------------------
author_name="$(git config --global user.name 2>/dev/null || true)"
author_email="$(git config --global user.email 2>/dev/null || true)"
if [[ -z "$author_name" ]]; then
    author_name="Henry Baker"
fi
if [[ -z "$author_email" ]]; then
    author_email="henry.c.g.baker@gmail.com"
fi

# ---------------------------------------------------------------------------
# Clean + recreate the generated tree (idempotent).
# ---------------------------------------------------------------------------
rm -rf "$OUT"
mkdir -p "$OUT/.claude-plugin" "$OUT/hooks"

# ---------------------------------------------------------------------------
# plugin.json — only `name` is required; we also set version/description/author.
# ---------------------------------------------------------------------------
jq -n \
    --arg name "$PLUGIN_NAME" \
    --arg version "$PLUGIN_VERSION" \
    --arg description "$PLUGIN_DESCRIPTION" \
    --arg author_name "$author_name" \
    --arg author_email "$author_email" \
    '{
        name: $name,
        version: $version,
        description: $description,
        author: { name: $author_name, email: $author_email }
    }' > "$OUT/.claude-plugin/plugin.json"

# ---------------------------------------------------------------------------
# hooks/hooks.json — take .hooks from settings.json verbatim (same event ->
# matcher -> hooks nesting as a plugin hooks.json wants) and repoint every
# command from the dotconfigs-deploy path (~/.claude/hooks/X.sh) to the
# installed-plugin path. Plugin hooks run in shell form, so wrap
# ${CLAUDE_PLUGIN_ROOT} in double quotes per the hooks reference.
# ---------------------------------------------------------------------------
jq '
    { hooks: .hooks }
    | (.hooks |= walk(
        if type == "object" and has("command") then
            .command |= sub("^~/\\.claude/hooks/"; "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/")
        else . end
      ))
' "$SETTINGS_SRC" > "$OUT/hooks/hooks.json"

# ---------------------------------------------------------------------------
# settings.json — everything EXCEPT the hooks block (those move to hooks.json).
# ---------------------------------------------------------------------------
jq 'del(.hooks)' "$SETTINGS_SRC" > "$OUT/settings.json"

# ---------------------------------------------------------------------------
# Symlink hook scripts back to source so edits propagate without a rebuild.
# Relative symlinks from claude-plugin/hooks/X.sh -> ../../plugins/claude/hooks/X.sh
# ---------------------------------------------------------------------------
for hook in "$SRC"/hooks/*.sh; do
    [[ -e "$hook" ]] || continue
    base="$(basename "$hook")"
    ln -s "../../plugins/claude/hooks/$base" "$OUT/hooks/$base"
done

# ---------------------------------------------------------------------------
# Symlink component directories back to source (relative).
# ---------------------------------------------------------------------------
ln -s "../plugins/claude/skills" "$OUT/skills"
ln -s "../plugins/claude/output-styles" "$OUT/output-styles"

echo "Built native plugin at: $OUT"
