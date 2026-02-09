---
phase: 09-config-ux-redesign
plan: 07
subsystem: infra
tags: [cleanup, tech-debt, documentation]

# Dependency graph
requires:
  - phase: 06-git-plugin
    provides: plugins/git/hooks/ directory as source of truth for git hooks
provides:
  - Legacy githooks/ directory removed
  - Orphaned discovery functions cleaned up
  - .env→JSON migration deferral documented
affects: []

# Tech tracking
tech-stack:
  added: []
  patterns: []

key-files:
  created: []
  modified:
    - lib/discovery.sh
    - .planning/ROADMAP.md
    - plugins/claude/setup.sh

key-decisions:
  - ".env format retained - JSON migration deferred to v3 (quoting bug was not symptomatic of format issues)"

patterns-established: []

# Metrics
duration: 2min
completed: 2026-02-09
---

# Phase 09 Plan 07: Gap Closure - Legacy Cleanup Summary

**Removed legacy githooks/ directory (2 outdated hooks), cleaned 3 orphaned discovery functions, documented .env→JSON deferral decision**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-09T13:59:10Z
- **Completed:** 2026-02-09T14:00:56Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Legacy githooks/ directory deleted (2 outdated hooks replaced by plugins/git/hooks/ with 7 hooks)
- Three orphaned discovery functions removed (discover_githooks, discover_settings_templates, discover_hooks_conf_profiles)
- .env→JSON migration decision documented in ROADMAP accumulated context

## Task Commits

Each task was committed atomically:

1. **Task 1: Remove legacy githooks/ directory and orphaned discovery functions** - `7e3b16a` (chore)
2. **Task 2: Record .env→JSON migration deferral in ROADMAP** - `23856cd` (docs)

## Files Created/Modified
- `lib/discovery.sh` - Removed 3 orphaned functions (51 lines deleted)
- `.planning/ROADMAP.md` - Added "Deferred to v3" section with .env→JSON rationale
- `plugins/claude/setup.sh` - Fixed opt-out logic (CLAUDE_GSD_INSTALL unset instead of "false")

## Decisions Made

**1. .env format retention**
- Current .env format works well after quick-002 quoting fix
- JSON would require jq dependency (bash 3.2 portability concern)
- JSON would need migration path for existing users
- Decision: Defer to v3 if need arises
- **Rationale:** Quoting bug was isolated issue, not symptomatic of deeper format problems

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Fixed boolean opt-out in claude setup.sh**
- **Found during:** Task 1 (commit staged the fix)
- **Issue:** CLAUDE_GSD_INSTALL opt-out set to "false" instead of leaving unset, breaking save function's `[[ -n "$VAR" ]]` check
- **Fix:** Changed opt-out from setting "false" to leaving variable unset in both category menu and edit mode
- **Files modified:** plugins/claude/setup.sh
- **Verification:** Unset variables correctly skipped by save function
- **Committed in:** 7e3b16a (Task 1 commit)

**2. [Rule 1 - Bug] Fixed .env header comments**
- **Found during:** Task 1 (commit staged the fix)
- **Issue:** .env header comments referenced "dots" instead of "dotconfigs" (stale from quick-002)
- **Fix:** Changed header references from "dots" to "dotconfigs"
- **Files modified:** plugins/claude/setup.sh
- **Verification:** Header comment accuracy checked
- **Committed in:** 7e3b16a (Task 1 commit)

---

**Total deviations:** 2 auto-fixed (1 missing critical, 1 bug)
**Impact on plan:** Both fixes address correctness issues introduced in Phase 9. No scope creep.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Legacy code cleanup complete
- .env→JSON decision documented for v3 planning reference
- Ready for plan 09-08 (README overhaul)

## Self-Check: PASSED

---
*Phase: 09-config-ux-redesign*
*Completed: 2026-02-09*
