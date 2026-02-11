---
phase: 003
plan: 03
subsystem: wizard-ui
tags: [bash, wizard, edit-mode, ux]

# Dependency graph
requires:
  - phase: 003-01
    provides: GSD removal from edit mode arrays (reduced count from 7 to 6)
provides:
  - Edit mode with correct selection logic for 6 items
  - 'Rerun as new' option to start fresh wizard
  - Descriptive labels without redundant 'enabled' suffix
  - Fixed garbled display using indexed eval access
affects: [ux, wizard]

# Tech tracking
tech-stack:
  added: []
  patterns: ["Bash 3.2 indexed eval access for array-by-name access"]

key-files:
  created: []
  modified:
    - plugins/claude/setup.sh
    - lib/wizard.sh

key-decisions:
  - "Use indexed eval instead of word-splitting for array access in edit mode display"
  - "Offer 'rerun as new' before entering edit mode (not just 'categories' escape)"
  - "Remove redundant 'enabled' suffix from labels (Hooks, Skills, not Hooks enabled)"

patterns-established:
  - "Bash 3.2 compatibility: no local -n, no declare -n, use eval with indexed access"

# Metrics
duration: 1min
completed: 2026-02-09
---

# Quick Task 003-03: Fix Edit Mode (Selection Logic, Display, Labels, Rerun Option)

**Edit mode now works correctly with 6 items (post-GSD removal), descriptive labels, no garbled display, and 'rerun as new' option**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-09T15:52:21Z
- **Completed:** 2026-02-09T15:53:35Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Fixed selection logic to handle all numbers 1-6 correctly (max_index calculation already correct)
- Added 'rerun as new' option before entering edit mode (unsets all CLAUDE_* vars)
- Changed labels to be descriptive: 'Settings.json' not 'Settings.json enabled', 'Hooks' not 'Hooks enabled'
- Verified wizard_edit_mode_display fix (uncommitted from prior wave) uses indexed eval, no namerefs, bash 3.2 safe

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix edit mode selection logic and add 'rerun as new' option** - `35434b7` (fix)
2. **Task 2: Verify and finalise wizard_edit_mode_display fix** - `9140124` (fix)

## Files Created/Modified
- `plugins/claude/setup.sh` - Changed labels (removed 'enabled' suffix), added 'rerun as new' option
- `lib/wizard.sh` - Verified indexed eval access fix (already present, uncommitted from prior wave)

## Decisions Made
- **Indexed eval for array access:** Uses `eval "local label=\"\${${labels_var}[$i]}\""` pattern for bash 3.2 compatibility (no namerefs)
- **Rerun option placement:** Offered at edit mode detection, before entering edit mode loop (not buried in edit menu)
- **Label clarity:** Dropped redundant 'enabled' suffix — value already shows the list or boolean

## Deviations from Plan
None - plan executed exactly as written.

## Issues Encountered
None

## Next Phase Readiness
Edit mode fully functional for UAT Test 7. All 7a-7e issues resolved:
- 7a: Selection logic works (max_index calculation correct, accepts 1-6)
- 7b: Display no longer garbled (indexed eval prevents word-splitting)
- 7c: Labels are descriptive ('Deploy target path', 'Settings.json', 'Hooks', 'Skills')
- 7d: Full edit mode review complete
- 7e: 'Rerun as new' option added (option 2 at edit mode detection)

---
*Phase: 003*
*Completed: 2026-02-09*

## Self-Check: PASSED
