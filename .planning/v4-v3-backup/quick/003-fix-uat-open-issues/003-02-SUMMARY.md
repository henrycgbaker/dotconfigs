---
phase: 003
plan: 02
subsystem: git-wizard-ux
tags: [git, wizard, ux, prompts]
requires: [003-01]
provides:
  - Clear opt-in prompts without config value confusion
  - Tracked/untracked labels for hook config paths
  - .claude/hooks.conf as config path option
  - Destination path in summary
affects: []
tech-stack:
  added: []
  patterns: [two-step-opt-in-flow]
key-files:
  created: []
  modified:
    - plugins/git/setup.sh
decisions:
  - PROMPT-01: "Two-step opt-in flow — ask to manage first, then show config value"
  - WORDING-01: "Aliases use 'add' not 'manage' (more user-friendly)"
  - DEFAULT-01: "First-run defaults to 'n' for manage questions (true opt-in)"
  - LABELS-01: "Config paths labeled tracked vs untracked"
metrics:
  duration: 2min
  completed: 2026-02-09
---

# Quick Task 003 Plan 02: Fix Git Wizard UX Issues Summary

**One-liner:** Git wizard prompts now cleanly separate opt-in from configuration, with tracked/untracked config path labels

## What Was Done

Fixed Git wizard UX issues from UAT Test 6:

### Task 1: Prompt Format and Alias Wording
- **Split confusing two-in-one prompts:** Changed from `Manage pull.rebase? (default: true) [Y/n]` to two-step flow:
  1. First ask: `Manage pull.rebase? [y/N]`
  2. Then prompt: `pull.rebase [true]` (if user opts in)
- **Fixed default logic:** First-run (unset vars) defaults to "n", existing config defaults to "y"
- **Applied to all workflow settings:** pull.rebase, push.default, fetch.prune, init.defaultBranch, rerere.enabled, diff.algorithm, help.autocorrect
- **Changed alias wording:** "Configure/manage git command aliases" → "Add git command aliases"
- **Commit:** `50daa1c`

### Task 2: Config Path Labels and Summary Destination
- **Added tracked/untracked indicators** to hook config path options:
  - Option 1: `.githooks/config` (tracked — committed to repo)
  - Option 2: `.claude/git-hooks.conf` (tracked — committed to repo)
  - Option 3: `.claude/hooks.conf` (tracked — committed to repo) ← NEW
  - Option 4: `.git/hooks/hooks.conf` (untracked — per-clone only)
  - Option 5: Custom path
- **Added .claude/hooks.conf option** (unified config file location)
- **Updated prompt** from `[1-4, default: 1]` to `[1-5, default: 1]`
- **Added destination path** to summary: "Settings will be saved to .env" in dim text
- **Commit:** `46d9d79`

## Decisions Made

### PROMPT-01: Two-Step Opt-In Flow
**Context:** Original prompts mixed "do you want to manage this?" with "what's the default value?" causing user confusion.

**Decision:** Split into two-step flow:
1. Ask to manage (yes/no)
2. If yes, show current value and prompt for input

**Rationale:** Clearer mental model. User first decides if they want to manage the setting, then configures it if they opted in. The `wizard_prompt` helper already shows `[default_value]` so the value is visible at the right time.

### WORDING-01: 'Add' Not 'Manage'
**Context:** Aliases section used "manage" wording like other sections, but aliases aren't being managed — they're being added.

**Decision:** Change to "Add git command aliases" and "select which to add".

**Rationale:** More accurate and user-friendly. You're adding aliases, not managing pre-existing ones.

### DEFAULT-01: First-Run Defaults to 'n'
**Context:** Original logic defaulted to "y" for any setting with a hardcoded default value, even on first run when user hasn't configured anything yet.

**Decision:** Default to "n" when env var is unset, "y" when var has a value from .env.

**Rationale:** True opt-in model. On first run, user hasn't expressed preference yet, so default to not managing. On re-run (edit mode), default to current state.

### LABELS-01: Tracked vs Untracked Config Paths
**Context:** Hook config path options didn't indicate which paths get committed to the repo vs which are per-clone only.

**Decision:** Add `(tracked — committed to repo)` and `(untracked — per-clone only)` labels.

**Rationale:** Users need to know the visibility/persistence implications of their choice. Tracked files affect all clones and collaborators, untracked files are local only.

## Deviations from Plan

None — plan executed exactly as written.

## Files Modified

### plugins/git/setup.sh
- `_git_wizard_workflow()`: Split all 7 workflow setting prompts into two-step opt-in flow
- `_git_wizard_workflow()`: Changed default logic from complex expressions to simple "n" or "y" based on env var presence
- `_git_wizard_aliases()`: Changed header and section text from "Configure/manage" to "Add"
- `_git_wizard_hooks()`: Added .claude/hooks.conf as option 3, added tracked/untracked labels to all 5 options
- `_git_wizard_summary()`: Added destination path line in dim text at end of summary

## Testing Notes

Verified:
- Syntax check passes: `bash -n plugins/git/setup.sh` ✓
- No `(default:` in wizard_yesno calls ✓ (0 occurrences)
- No "manage" in aliases user-facing text ✓ (0 occurrences)
- `.claude/hooks.conf` appears as config option ✓ (2 occurrences)

## Next Phase Readiness

**Ready for:** 003-03 (next UAT fix), 003-04 (final UAT fix)

**Unblocked:** This fixes UAT Test 6 UX issues. No new blockers introduced.

**Concerns:** None.

## Self-Check: PASSED

All commits exist:
- `50daa1c` ✓
- `46d9d79` ✓

All modified files exist:
- `plugins/git/setup.sh` ✓
