---
phase: 09
plan: 04
subsystem: git-wizard
tags: [bash, wizard-ux, opt-in, select-replacement]

requires:
  - 09-01
  - 09-02

provides:
  - category-based-opt-in-wizard
  - edit-mode-reconfiguration
  - read-based-prompts

affects:
  - 09-05

tech-stack:
  added: []
  patterns:
    - category-menu-wizard-flow
    - opt-in-config-selection
    - edit-mode-detection

key-files:
  created: []
  modified:
    - plugins/git/setup.sh

decisions:
  - decision: Four categories for Git config (Identity, Workflow, Aliases, Hooks)
    rationale: Natural grouping based on existing wizard sections and user mental model
    date: 2026-02-09

  - decision: Replace select loops with read-based numbered prompts
    rationale: Aligns with UX consistency goal across all wizards (success criteria)
    date: 2026-02-09

  - decision: Edit mode triggered by presence of any GIT_* keys in .env
    rationale: Simple detection heuristic that works for all config categories
    date: 2026-02-09

metrics:
  duration: 2.5min
  completed: 2026-02-09
---

# Phase 9 Plan 4: Git Wizard Opt-in Redesign Summary

**One-liner:** Opt-in category-based Git wizard with read prompts and edit mode

## What Was Built

Completely rewrote the Git global-configs wizard (`plugins/git/setup.sh`) with:

1. **Category-based opt-in model:** 4 categories (Identity, Workflow, Aliases, Hooks)
2. **Read-based prompts:** Replaced both remaining `select` loops with numbered `read` prompts
3. **Edit mode:** Detects existing config and shows current state for reconfiguration
4. **Opt-in saving:** Only writes opted-in configs to .env; unselected configs show as `[not managed]`

## Verification Results

All verification checks passed:

- ✅ No `select` loops remain (grep returns 0 for actual select statements)
- ✅ Identity category present (6 mentions)
- ✅ Workflow category present (6 mentions)
- ✅ Aliases category present (6 mentions)
- ✅ Hooks category present (7 mentions)
- ✅ `[not managed]` status shown (28 occurrences in summary)
- ✅ Edit mode implemented (8 references)
- ✅ No bash 4+ syntax (0 occurrences of namerefs/associative arrays)

## Task Commits

| Task | Description | Commit | Files |
|------|-------------|--------|-------|
| 1 | Rewrite Git wizard with opt-in categories and read prompts | 40fcde9 | plugins/git/setup.sh |

## Key Implementation Details

### Category Structure

**Identity:**
- Git user.name
- Git user.email

**Workflow:**
- Core: pull.rebase, push.default, fetch.prune, init.defaultBranch
- Advanced: rerere.enabled, diff.algorithm, help.autocorrect

**Aliases:**
- Default aliases: unstage, last, lg, amend, undo, wip
- Custom aliases (user-defined)

**Hooks:**
- Hooks scope (project/global)
- Config file location
- Pre-commit checks (secrets, large file, debug)
- Commit message validation
- Pre-push protection
- Post-merge/rewrite helpers
- Post-checkout
- Advanced settings

### Select Loop Replacements

1. **Hook config path** (line ~201):
   - Old: `select config_path in ...`
   - New: Numbered read prompt with case statement

2. **Branch protection level** (line ~290):
   - Old: `select protection_level in ...`
   - New: Numbered read prompt with case statement

### Edit Mode Flow

First-run:
1. Show category menu (1-6)
2. User picks categories to configure
3. Each category runs opt-in prompts
4. Summary shows managed vs not managed
5. Confirm and save

Re-run (edit mode):
1. Detect existing GIT_* keys in .env
2. Show current state with [not managed] indicators
3. User picks categories to reconfigure
4. Only selected categories re-prompted
5. Summary and save

### Opt-in Model

- Workflow: Each setting asks "Manage X?" → if no, unset variable
- Save: Only writes keys that have values (opt-in)
- Summary: Shows `[not managed]` for unset configs

## Deviations from Plan

None — plan executed exactly as written.

## Next Phase Readiness

**Phase 9, Plan 5 (Claude wizard redesign):**
- ✅ Git wizard pattern established
- ✅ Category-based opt-in model validated
- ✅ Edit mode pattern ready to replicate
- ✅ No blockers

**Integration points:**
- Claude wizard should follow same pattern (4 categories, edit mode, opt-in)
- Both wizards now use read prompts exclusively

## Lessons Learned

1. **Category selection:** Balancing granularity (4 categories vs 7+ individual sections) improves UX
2. **Edit mode detection:** Simple heuristic (any GIT_* key) works better than complex state tracking
3. **Opt-in vs default:** Unset variables better than writing defaults (user intent clearer)

## Self-Check: PASSED

Created files: N/A (docs-only check skipped)

Commits:
- ✅ 40fcde9 exists
