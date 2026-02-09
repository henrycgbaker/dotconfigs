---
phase: 09-config-ux-redesign
plan: "03"
subsystem: config-wizard
tags: [wizard, ux, opt-in, categories, edit-mode, bash]
requires: [09-01, 09-02]
provides:
  - opt-in category-based Claude config wizard
  - edit mode for re-runs with managed/not-managed indicators
  - 3-category structure (Deploy targets, Content, Behaviour)
affects: [09-04]
tech-stack:
  added: []
  patterns: [opt-in-config-selection, edit-mode-wizard, category-based-ux]
key-files:
  created: []
  modified:
    - plugins/claude/setup.sh
decisions:
  - id: WIZARD-01
    decision: "Remove git identity from Claude wizard (moved to git plugin in Plan 04)"
    rationale: "Git identity belongs in git plugin, not Claude plugin"
    alternatives: "Keep in Claude wizard (rejected: wrong separation of concerns)"
  - id: WIZARD-02
    decision: "Edit mode as default on re-runs (detect via CLAUDE_DEPLOY_TARGET presence)"
    rationale: "More efficient for users who want to tweak one value"
    alternatives: "Always show category menu (rejected: forces full re-walk)"
  - id: WIZARD-03
    decision: "First-run defaults to ALL sections/hooks/skills enabled"
    rationale: "Opinionated defaults — user opts out if unwanted"
    alternatives: "Start with nothing selected (rejected: forces many selections)"
metrics:
  tasks: 1
  commits: 1
  duration: 123s
  completed: 2026-02-09
---

# Phase 09 Plan 03: Rewrite Claude Wizard with Opt-in Categories Summary

Category-based opt-in wizard with edit mode for Claude global-configs.

## What Was Built

Complete rewrite of `plugins/claude/setup.sh` implementing:

1. **Category-based structure (3 categories):**
   - Deploy targets: path + GSD install
   - Content: CLAUDE.md sections + skills
   - Behaviour: settings.json + CLAUDE.md exclusion + hooks

2. **First-run flow:**
   - Category menu (user picks which to configure)
   - Each category uses toggle helpers for multi-select
   - Opinionated defaults: all sections/hooks/skills enabled by default
   - Summary with managed/not-managed indicators
   - Confirm before save

3. **Edit mode (on re-run):**
   - Detects existing config via `CLAUDE_DEPLOY_TARGET` presence
   - Shows numbered list: `[1] Deploy target path = ~/.claude`
   - User enters numbers to edit (e.g. "3,6")
   - Can type 'categories' to switch to category menu
   - Only modified values re-prompted

4. **Opt-in save logic:**
   - `_claude_save_config()` only writes non-empty values
   - Unselected configs = no .env key written
   - Arrays (sections/hooks/skills) only saved if non-empty

5. **Git identity removed:**
   - `CLAUDE_GIT_USER_NAME` and `CLAUDE_GIT_USER_EMAIL` removed from wizard
   - Migration logic kept for backwards compat
   - Will be handled by git plugin (Plan 04)

## Technical Implementation

**Bash 3.2 compatibility maintained:**
- No namerefs (`local -n`)
- No associative arrays (`declare -A`)
- Indexed arrays with eval for indirect access
- `tr '[:upper:]' '[:lower:]'` for case conversion

**Wizard helpers used:**
- `wizard_config_toggle` — checkbox menu with all/none/done
- `wizard_edit_mode_display` — numbered list with [not managed] badges
- `wizard_parse_edit_selection` — comma-separated number parsing
- `colour_not_managed` — dim badge for unmanaged configs

**Flow control:**
- Edit mode returns 0 for 'done', 1 for 'categories' (switch to category menu)
- Category menu loops until user selects "Done — show summary"
- "Configure all" option walks through all 3 categories sequentially

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Rewrite Claude wizard with opt-in categories | ff025b5 | plugins/claude/setup.sh |

## Deviations from Plan

None — plan executed exactly as written.

## Key Learnings

**Category-based UX significantly reduces cognitive load:**
- User can focus on one domain at a time
- "Configure all" option for power users who want full walk-through
- Edit mode reduces friction for single-value changes

**Opt-in model requires careful empty checks:**
- Arrays: `[[ ${#array[@]} -gt 0 ]]`
- Strings: `[[ -n "$var" ]]`
- Save logic must skip unset values to prevent writing empty keys

**Edit mode + category menu hybrid approach:**
- Edit mode for quick tweaks (most common on re-run)
- Category menu still accessible via 'categories' escape hatch
- Best of both worlds

## Testing Notes

**Manual testing required:**
1. First run: verify category menu works
2. Select subset of configs, verify only those written to .env
3. Re-run: verify edit mode shows current state
4. Edit mode: pick numbers, verify only those re-prompted
5. Type 'categories' from edit mode, verify menu appears
6. Verify [not managed] appears for unselected configs in summary

**Verification commands:**
```bash
# Run wizard
./dotconfigs global-configs claude

# Check .env only has selected keys
grep "CLAUDE_" .env

# Re-run, verify edit mode activates
./dotconfigs global-configs claude
```

## Next Phase Readiness

**Blockers:** None

**Handoff to Plan 04:**
- Git identity config responsibility moved to git plugin
- Git plugin must handle `CLAUDE_GIT_USER_NAME` and `CLAUDE_GIT_USER_EMAIL` migration
- Migration logic already in place (comments out old keys)

## Self-Check: PASSED

All commits verified:
- ff025b5 exists in git log

All created files verified:
- (none — this plan only modified existing file)

All modified files verified:
- plugins/claude/setup.sh exists and rewritten
