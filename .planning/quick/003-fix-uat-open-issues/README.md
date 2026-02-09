# 003 — Fix UAT Open Issues

Fixes all open UAT issues from `.planning/phases/v2.0-integrated-UAT.md` (Tests 5, 6, 7, 11).

## Plans

| Plan | Wave | Objective | Files |
|------|------|-----------|-------|
| 003-01 | 1 | Claude wizard: remove GSD, add previews, simplify settings, fix exclusion, surface hooks/skills | `plugins/claude/setup.sh`, `plugins/claude/deploy.sh`, `settings.json` |
| 003-02 | 1 | Git wizard: fix prompts, alias wording, config labels, summary path, .claude/hooks.conf | `plugins/git/setup.sh` |
| 003-03 | 2 | Edit mode repair: fix display, selection, labels, add 'rerun as new' | `lib/wizard.sh`, `plugins/claude/setup.sh` |
| 003-04 | 1 | Setup command: polish one-time init, simplify legacy path | `dotconfigs` |

## Wave Structure

- **Wave 1** (parallel): 003-01, 003-02, 003-04
- **Wave 2** (sequential): 003-03 (depends on 003-01 for GSD removal)

## Deferred

- **Test 6c**: Per-hook granularity for scope (global vs project) and location — requires major rearchitecture of hook deployment model. Current all-or-nothing scope is functional.

## Uncommitted Changes

The following uncommitted changes are partially correct and should be preserved:
- `lib/wizard.sh`: Fixed `wizard_edit_mode_display()` — uses indexed eval instead of word-splitting
- `plugins/claude/setup.sh`: GSD wording improvements, CLAUDE.md 'both' option in edit mode
- `settings.json`: Simplified structure (matches single-template approach)

These changes are built upon, not discarded.
