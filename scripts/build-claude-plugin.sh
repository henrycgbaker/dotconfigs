#!/usr/bin/env bash
# Build the native Claude Code plugin into top-level claude-plugin/.
#
# Generates an installable Claude Code plugin FROM the dotconfigs plugin source
# at plugins/claude/ (hooks, skills, output-styles, settings.json). The output
# is committed so installers needn't run this build.
#
# What it produces under claude-plugin/:
#   .claude-plugin/plugin.json  — generated manifest (name/version/desc/author)
#   hooks/hooks.json            — synthesised from the wired Claude hooks in the
#                                 manifest, with commands repointed at ${CLAUDE_PLUGIN_ROOT}
#   hooks/*.sh                  — relative symlinks back to plugins/claude/hooks/*.sh
#   skills/                     — relative symlink to ../plugins/claude/skills
#   output-styles/              — relative symlink to ../plugins/claude/output-styles
#   settings.json               — non-hook portion of plugins/claude/settings.json
#   README.md                   — generated; explains this is a build artifact
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
author_name="$(git config --global --includes user.name 2>/dev/null || true)"
author_email="$(git config --global --includes user.email 2>/dev/null || true)"
author_name="${author_name:-Henry Baker}"
author_email="${author_email:-henry.c.g.baker@gmail.com}"

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
# hooks/hooks.json — synthesise the event -> matcher -> hooks nesting from the
# selected, wired Claude hooks (same source the deploy engine uses), then
# repoint every command from the dotconfigs-deploy path (~/.claude/hooks/X.sh)
# to the installed-plugin path. Plugin hooks run in shell form, so wrap
# ${CLAUDE_PLUGIN_ROOT} in double quotes per the hooks reference.
# ---------------------------------------------------------------------------
# shellcheck source=../src/lib/deploy.sh
source "$REPO_ROOT/src/lib/deploy.sh"
# Ship the default-on hook set: a selection mirroring each hook's `default`.
sel_tmp="$(mktemp "${TMPDIR:-/tmp}/dots-plugin-sel.XXXXXX")"
jq -n --slurpfile m "$SRC/manifest.json" \
    '{ claude: ($m[0] | map_values(map_values(.default // false))) }' > "$sel_tmp"
synthesise_claude_hooks "$REPO_ROOT/plugins" "$sel_tmp" | jq '
    { hooks: . }
    | (.hooks |= walk(
        if type == "object" and has("command") then
            .command |= sub("^~/\\.claude/hooks/"; "\"${CLAUDE_PLUGIN_ROOT}\"/hooks/")
        else . end
      ))
' > "$OUT/hooks/hooks.json"
rm -f "$sel_tmp"

# ---------------------------------------------------------------------------
# settings.json — everything EXCEPT the hooks block (those move to hooks.json).
# Also bake in author attribution: the dotconfigs deploy path substitutes the
# {{AUTHOR_*}} placeholders at deploy time, but a marketplace install never runs
# that step, so substitute them here (mirror lib/deploy.sh _substitute_placeholders).
# ---------------------------------------------------------------------------
jq --arg name "$author_name" --arg email "$author_email" '
    del(.hooks)
    | walk(if type == "string" then
        gsub("\\{\\{AUTHOR_NAME\\}\\}"; $name) | gsub("\\{\\{AUTHOR_EMAIL\\}\\}"; $email)
      else . end)
' "$SETTINGS_SRC" > "$OUT/settings.json"

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

# ---------------------------------------------------------------------------
# README — explains this is a generated artifact (regenerated each build, so it
# must be emitted here rather than hand-added, or it would be wiped).
# ---------------------------------------------------------------------------
cat > "$OUT/README.md" <<'README'
# dots — native Claude Code plugin (generated)

> **Generated artifact — do not edit by hand.** This whole directory is rebuilt
> by `scripts/build-claude-plugin.sh` from `plugins/claude/` (which is the single
> source of truth). Edit the source there and re-run the build; any manual change
> here is wiped on the next build.

This is the [`plugins/claude/`](../plugins/claude/) configuration — safety hooks,
git-workflow skills, and the concise-execution output style — packaged as an
installable **Claude Code plugin** named `dots`. It is committed so it can be
installed without cloning dotconfigs or running the symlink deploy.

## Install (from inside Claude Code)

```
/plugin marketplace add henrycgbaker/dotconfigs
/plugin install dots
```

Installed this way the skills are **namespaced** — `/dots:commit`,
`/dots:squash-merge`, etc. (a full `dotconfigs deploy` installs them un-namespaced).

## Two distribution paths, one source

| Path | What it does |
|------|--------------|
| `dotconfigs deploy` | symlinks `plugins/claude/` into `~/.claude/` (the main path; hooks wired into `~/.claude/settings.json`) |
| this `dots` plugin  | a native Claude Code plugin install — no clone/deploy needed |

## What's in here

- `.claude-plugin/plugin.json` — generated manifest (name/version/description/author).
- `hooks/hooks.json` — the hook wiring, **synthesised** from each hook's `wiring` in
  `plugins/claude/manifest.json` (the same source the deploy engine uses), with commands
  repointed at `${CLAUDE_PLUGIN_ROOT}`.
- `hooks/*.sh` — relative symlinks back to `plugins/claude/hooks/`.
- `skills/`, `output-styles/` — relative symlinks to `plugins/claude/`.
- `settings.json` — the non-hooks portion of `plugins/claude/settings.json`.

To refresh after editing the source: `scripts/build-claude-plugin.sh`.
README

echo "Built native plugin at: $OUT"
