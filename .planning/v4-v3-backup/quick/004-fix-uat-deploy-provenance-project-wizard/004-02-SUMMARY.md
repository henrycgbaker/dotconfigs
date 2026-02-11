---
phase: 004-fix-uat-deploy-provenance-project-wizard
plan: 02
subsystem: cli
tags: [wizard, stdin, interactive, prompts, project-configs]

# Dependency graph
requires:
  - phase: 004-01
    provides: Deploy source provenance (also fixed hooks.json and CLAUDE.md builder as deviation)
provides:
  - Fixed stdin consumption in cmd_project_configs all-plugins loop
  - Interactive wizard_yesno prompts in project-configs wizard
  - Section-based CLAUDE.md assembly (completed in 004-01)
  - Correct .claude/hooks/ paths in hooks.json template (completed in 004-01)
affects: [project-configs, wizard-functions]

# Tech tracking
tech-stack:
  added: []
  patterns: [array-based plugin collection to preserve stdin]

key-files:
  created: []
  modified:
    - dotconfigs
    - plugins/claude/project.sh
    - plugins/claude/templates/settings/hooks.json

key-decisions:
  - "Collect plugins into array before iteration to avoid stdin redirection"
  - "Task 2 work already completed in 004-01 (deviation from that plan)"

patterns-established:
  - "Avoid stdin redirection in loops that call interactive functions"
  - "Separate discovery (stdin-consuming) from execution (interactive)"

# Metrics
duration: 2min
completed: 2026-02-09
---

# Plan 004-02: Fix Broken Project-Configs Wizard

**Interactive project-configs wizard with stdin-preserving loop and section-based CLAUDE.md assembly**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-09T19:04:01Z
- **Completed:** 2026-02-09T19:05:53Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed stdin consumption bug causing wizard_yesno prompts to fall through
- Verified section-based CLAUDE.md assembly already working (from 004-01)
- Verified hooks.json template paths already corrected (from 004-01)

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix stdin consumption in cmd_project_configs all-plugins loop** - `5be5c68` (fix)
2. **Task 2: Replace hardcoded CLAUDE.md with section-based assembly + fix hook paths** - Already completed in `a461bbc` (004-01)

## Files Created/Modified
- `dotconfigs` - Fixed all-plugins loop to collect into array before iteration
- `plugins/claude/project.sh` - Section-based CLAUDE.md builder (already present from 004-01)
- `plugins/claude/templates/settings/hooks.json` - Correct .claude/hooks/ paths (already present from 004-01)

## Decisions Made

**Decision 1: Array-based plugin collection**
Collect plugins into array first, then iterate with for loop. Prevents stdin redirection from consuming wizard_yesno read calls.

**Decision 2: Task 2 already complete**
Task 2 fixes (CLAUDE.md builder, hooks.json paths) were already implemented in 004-01 as a deviation from that plan. Verified changes are correct and complete.

## Deviations from Plan

### Work Already Completed in Prior Plan

**Task 2 work completed in 004-01**
- **Context:** Plan 004-01 was scoped for deploy source provenance only
- **What happened:** 004-01 executor also fixed hooks.json paths and implemented CLAUDE.md section builder
- **Verification:** All Task 2 requirements already present:
  - `_claude_build_md()` called with CLAUDE_MD_SECTIONS
  - hooks.json uses `.claude/hooks/` paths (not `$CLAUDE_PROJECT_DIR`)
  - Wizard prompt changed to "Create project CLAUDE.md from global sections?"
- **Impact:** Task 2 was verify-only, no additional commits needed
- **Deviation type:** Rule 2 or 3 applied by 004-01 executor (likely Rule 2 - critical functionality)

---

**Total deviations:** 1 (work completed in prior plan)
**Impact on plan:** No negative impact. Task 2 requirements fully met. Only Task 1 required new commits.

## Issues Encountered
None

## Next Phase Readiness
- Project-configs wizard fully interactive
- All three UAT test 13 issues resolved
- Ready for UAT re-test

---
*Phase: 004-fix-uat-deploy-provenance-project-wizard*
*Completed: 2026-02-09*

## Self-Check: PASSED
