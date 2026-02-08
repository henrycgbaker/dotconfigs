---
phase: 05-claude-plugin-extraction
plan: 01
subsystem: plugin-architecture
tags: [refactoring, plugin-structure, discovery, bash]
requires: [04-02]
provides:
  - Claude plugin directory structure (plugins/claude/)
  - Plugin-relative asset discovery
  - Unified dotconfigs naming in lib/
affects: [05-02, 05-03, 05-04]
decisions:
  - "Assets organized under plugins/claude/ with subdirectories for templates, hooks, commands"
  - "Discovery functions accept plugin_dir parameter for flexibility"
  - "discover_hooks_conf_profiles function added for hooks.conf profile discovery"
  - "All lib/ references changed from dotclaude to dotconfigs"
tech-stack:
  added: []
  patterns: [plugin-relative-paths, filesystem-discovery]
key-files:
  created:
    - plugins/claude/DESCRIPTION
  modified:
    - lib/discovery.sh
    - lib/symlinks.sh
metrics:
  duration: 139s
  completed: 2026-02-07
---

# Phase [05] Plan [01]: Claude Plugin Asset Migration Summary

**One-liner:** Relocated all Claude-specific assets into plugins/claude/, updated discovery functions for plugin-relative paths, renamed dotclaude to dotconfigs throughout lib/.

## What Was Built

### Task 1: Move assets into plugins/claude/
Moved all Claude-specific assets from root-level directories into the plugin structure:

**Templates moved:**
- `templates/claude-md/` → `plugins/claude/templates/claude-md/` (5 .md files)
- `templates/settings/` → `plugins/claude/templates/settings/` (3 .json files)
- `templates/hooks-conf/` → `plugins/claude/templates/hooks-conf/` (3 .conf files)

**Hooks moved:**
- `hooks/post-tool-format.py` → `plugins/claude/hooks/post-tool-format.py`

**Commands moved:**
- `commands/*.md` → `plugins/claude/commands/*.md` (4 files: commit, squash-merge, simplicity-check, pr-review)

**Created:**
- `plugins/claude/DESCRIPTION` with one-line description for `dotconfigs list` output

**Removed:**
- Empty root-level `templates/`, `hooks/`, and `commands/` directories

### Task 2: Update discovery functions for plugin-relative paths
Updated `lib/discovery.sh` to accept plugin directory as base path:

**Updated functions:**
- `discover_hooks($plugin_dir)` — changed from `$dotclaude_root/hooks` to `$plugin_dir/hooks`
- `discover_skills($plugin_dir)` — changed from `$dotclaude_root/commands` to `$plugin_dir/commands`
- `discover_claude_sections($plugin_dir)` — changed from `$dotclaude_root/templates/claude-md` to `$plugin_dir/templates/claude-md`
- `discover_settings_templates($plugin_dir)` — changed from `$dotclaude_root/templates/settings` to `$plugin_dir/templates/settings`
- `discover_githooks($dotconfigs_root)` — renamed parameter from `dotclaude_root` to `dotconfigs_root`

**Added function:**
- `discover_hooks_conf_profiles($plugin_dir)` — lists available hooks.conf profiles from `$plugin_dir/templates/hooks-conf/`

This enables callers to pass `$PLUGINS_DIR/claude` instead of hardcoded root paths, supporting the plugin architecture.

### Task 3: Rename dotclaude references to dotconfigs in lib/
Completed the repo rename from dotclaude to dotconfigs in the shared library layer:

**lib/symlinks.sh changes:**
- Function: `is_dotclaude_owned()` → `is_dotconfigs_owned()`
- Variables: `dotclaude_path` → `dotconfigs_path`, `dotclaude_root` → `dotconfigs_root`
- Comments: Updated all references from "dotclaude repo" to "dotconfigs repo"
- User-facing string: "not managed by dotclaude" → "not managed by dotconfigs"

**lib/discovery.sh changes:**
- Parameter rename in `discover_githooks()` from `dotclaude_root` to `dotconfigs_root`
- Comment updates for consistency

**Verification:** Zero `dotclaude` references remain in `lib/` directory.

## Task Commits

| Task | Name                                             | Commit  | Files Modified                                      |
|------|--------------------------------------------------|---------|-----------------------------------------------------|
| 1    | Move assets into plugins/claude/                 | ce7f7ca | 17 files (16 moved, 1 created)                      |
| 2    | Update discovery functions for plugin-relative paths | 601e679 | lib/discovery.sh                                    |
| 3    | Rename dotclaude references to dotconfigs in lib/ | b01a1c3 | lib/symlinks.sh                                     |

## Deviations from Plan

None — plan executed exactly as written.

## Decisions Made

1. **Plugin directory structure**: Assets organized under `plugins/claude/` with clear subdirectories (templates/, hooks/, commands/). This makes the plugin self-contained and easy to discover.

2. **Discovery function parameter naming**: Used `plugin_dir` for Claude-specific discovery functions and `dotconfigs_root` for git hooks discovery (which remain at repo root). This clearly signals the scope difference.

3. **hooks-conf profile discovery**: Added `discover_hooks_conf_profiles()` function to match the pattern of other template discovery functions, enabling future setup wizards to list available profiles.

4. **Complete dotclaude→dotconfigs rename in lib/**: Changed all function names, variables, comments, and user-facing strings to ensure consistency across the shared library layer.

## Testing Results

**Verification checks passed:**
- ✅ 19 files exist under `plugins/claude/` (exceeds minimum of 13)
- ✅ `bash -n` syntax check passes for both `lib/discovery.sh` and `lib/symlinks.sh`
- ✅ Root-level `templates/`, `hooks/`, `commands/` directories removed
- ✅ Zero `dotclaude` references remain in `lib/`
- ✅ All git operations used `git mv` to preserve history
- ✅ No bash 4+ syntax introduced (macOS bash 3.2 compatible)

**File counts verified:**
- 5 CLAUDE.md section templates
- 3 settings templates
- 3 hooks-conf profiles
- 1 Claude Code hook
- 4 command skills
- 1 DESCRIPTION file

## Next Phase Readiness

**Unblocks:**
- **05-02 (Setup Wizard)**: Can now discover and deploy assets from `plugins/claude/`
- **05-03 (Deploy Logic)**: Discovery functions ready to use with `$PLUGINS_DIR/claude` path
- **05-04 (Integration)**: Plugin structure in place for `dotconfigs` entry point integration

**Dependencies satisfied:**
- Plugin structure established as required by CLPL-03
- Discovery functions support plugin-relative paths
- Naming consistency achieved (dotconfigs throughout)

**Known issues:**
- None — all assets successfully relocated and verified
- Post-tool hook temporarily unavailable during execution (expected, assets moved)

**Documentation needs:**
- Future: Update developer docs to reflect new plugin structure (deferred to v3)
- Setup/deploy scripts will need to call discovery functions with new paths (05-02, 05-03)

## Self-Check: PASSED

**Files verified:**
- ✅ plugins/claude/DESCRIPTION
- ✅ plugins/claude/templates/claude-md/01-communication.md
- ✅ plugins/claude/templates/claude-md/02-simplicity.md
- ✅ plugins/claude/templates/claude-md/03-documentation.md
- ✅ plugins/claude/templates/claude-md/04-git.md
- ✅ plugins/claude/templates/claude-md/05-code-style.md
- ✅ plugins/claude/templates/settings/base.json
- ✅ plugins/claude/templates/settings/node.json
- ✅ plugins/claude/templates/settings/python.json
- ✅ plugins/claude/templates/hooks-conf/default.conf
- ✅ plugins/claude/templates/hooks-conf/permissive.conf
- ✅ plugins/claude/templates/hooks-conf/strict.conf
- ✅ plugins/claude/hooks/post-tool-format.py
- ✅ plugins/claude/commands/commit.md
- ✅ plugins/claude/commands/squash-merge.md
- ✅ plugins/claude/commands/simplicity-check.md
- ✅ plugins/claude/commands/pr-review.md

**Commits verified:**
- ✅ ce7f7ca (Task 1: Move assets)
- ✅ 601e679 (Task 2: Update discovery)
- ✅ b01a1c3 (Task 3: Rename dotclaude)
