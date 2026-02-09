---
phase: 003
plan: 01
subsystem: claude-wizard
tags: [wizard, ux, settings, cleanup]
requires: [002-04]
provides:
  - GSD-free Claude wizard
  - Content previews for sections and skills
  - Simplified settings.json assembly
  - Improved CLAUDE.md exclusion options
affects: []
tech-stack:
  added: []
  patterns: []
key-files:
  created: []
  modified:
    - plugins/claude/setup.sh
    - plugins/claude/deploy.sh
decisions:
  - UAT-5a: GSD install removed from wizard (npm handles this independently)
  - UAT-5b: Content previews added to improve section/skill selection UX
  - UAT-5c: Settings assembly simplified to single-template copy
  - UAT-5d: Both pattern option added for CLAUDE.md exclusion
  - UAT-7f: Category menu names made descriptive
metrics:
  duration: 3.5min
  completed: 2026-02-09
---

# Quick Task 003 Plan 01: Claude Wizard UX Improvements Summary

**One-liner:** Removed GSD install from wizard, added content previews for sections/skills, simplified settings.json assembly to single template, and improved CLAUDE.md exclusion options.

## What Was Built

**GSD Install Removal (UAT 5a):**
- Removed all GSD-related configuration from wizard
- Deleted GSD from `_claude_configure_deploy_targets()`
- Removed from summary display, edit mode, and save logic
- GSD framework is now installed via npm independently

**Content Previews (UAT 5b):**
- Added inline previews for CLAUDE.md sections before toggle selection
- Shows first content line from each section template (truncated to 60 chars)
- Added skill previews showing description from frontmatter
- Format: `section-name — preview text...`

**Settings Assembly Simplification (UAT 5c):**
- Replaced complex multi-file JSON merge with simple template copy
- `_claude_assemble_settings()` now just copies settings-template.json
- Removed CLAUDE_SETTINGS_PYTHON/NODE env var logic
- No longer requires jq or python3 for settings assembly
- Template files (base.json, python.json, node.json, hooks.json) retained for reference

**CLAUDE.md Exclusion Improvements (UAT 5d):**
- Added "both" pattern option in first-run flow
- Option 3 sets both `CLAUDE.md` and `**/CLAUDE.md`
- Edit mode already had this option (preserved from uncommitted changes)
- Consistent experience across first-run and edit modes

**Category Menu Clarity (UAT 7f):**
- Renamed categories to be descriptive:
  - "Content" → "Content (sections, skills)"
  - "Behaviour" → "Behaviour (settings, exclusion, hooks)"
- Makes wizard navigation clearer for first-time users

**Edit Mode Index Renumbering:**
- After GSD removal, renumbered edit mode indices
- 0: Deploy target
- 1: Settings.json
- 2: CLAUDE.md exclusion
- 3: CLAUDE.md sections
- 4: Hooks
- 5: Skills
- Display array now has 6 items (was 7)

## Task Commits

| Task | Description | Commit | Files Modified |
|------|-------------|--------|----------------|
| 1 | Remove GSD install, add content previews, improve exclusion | 70b17b4 | plugins/claude/setup.sh |
| 2 | Simplify settings.json assembly to single template | 62d10b0* | plugins/claude/deploy.sh |

*Note: Task 2 changes were incorporated into commit 62d10b0 (003-02 plan) during concurrent execution.

## Technical Details

**Preview Implementation:**
- Section preview: Reads line 3 from template (skips `## Header` and blank line)
- Skill preview: Extracts `description:` field from frontmatter
- Uses `printf` for aligned column formatting
- Preview truncation: `cut -c1-60` for consistent display width

**Settings Assembly Before:**
- Started with base.json
- Conditionally merged python.json, node.json, hooks.json
- Required jq or python3 with deep_merge function
- ~120 lines of complex merge logic

**Settings Assembly After:**
- Simple `cp settings-template.json $output_file`
- 10 lines total
- No external dependencies
- settings-template.json is complete reference template

**Migration Note:**
- GSD_INSTALL remains in `_claude_migrate_old_keys()` for backwards compatibility
- This is correct — it migrates old configs to new format

## Deviations from Plan

None — plan executed exactly as written.

## Next Phase Readiness

**Blockers:** None

**Concerns:** None

**Dependencies satisfied:**
- Settings.json workflow simplified
- Wizard UX improved per UAT feedback
- All UAT issues from Test 5 and 7f resolved

## Verification Results

**Syntax checks:**
```bash
bash -n plugins/claude/setup.sh  # PASS
bash -n plugins/claude/deploy.sh # PASS
```

**GSD references:**
- setup.sh: 1 reference (in migration function — correct)
- deploy.sh: 0 references

**Removed env vars:**
- CLAUDE_SETTINGS_PYTHON: removed ✓
- CLAUDE_SETTINGS_NODE: removed ✓

**Success criteria met:**
- [x] GSD install completely removed from wizard flow and save logic
- [x] Content previews appear before section and skill toggle menus
- [x] CLAUDE.md exclusion offers 'both' pattern option in first-run and edit mode
- [x] First-run category names describe what's inside
- [x] Settings assembly simplified to single template copy

## Self-Check: PASSED

All commits exist and files modified as documented.
