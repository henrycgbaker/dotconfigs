---
phase: 07-integration-and-polish
plan: 05
subsystem: cli
tags: [bash, path, symlink, ux]

# Dependency graph
requires:
  - phase: 07-03
    provides: Deploy command with dry-run, force, and summary
provides:
  - PATH symlink creation during deploy for global CLI access
  - Smart CWD detection for project command (optional path argument)
affects: [v3-shell-plugin]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "PATH symlink at ~/.local/bin (preferred) or /usr/local/bin (fallback)"
    - "CWD detection with explicit confirmation prompt"
    - "Reject dotconfigs repo as project target"

key-files:
  created: []
  modified:
    - "dotconfigs"

key-decisions:
  - "Prefer ~/.local/bin over /usr/local/bin (no sudo required)"
  - "Use -ef test for same directory check (POSIX-compatible)"
  - "Default to 'yes' on CWD confirmation (optimistic UX)"

patterns-established:
  - "Symlink creation: idempotent, fail-gracefully, respect dry-run/force"
  - "Path detection: reject self-reference, confirm with user, fall back to explicit"

# Metrics
duration: 2.5min
completed: 2026-02-07
---

# Phase 07 Plan 05: CLI Usability Summary

**PATH symlink creation for global CLI access and smart CWD detection for project command**

## Performance

- **Duration:** 2.5 min
- **Started:** 2026-02-07T19:28:14Z
- **Completed:** 2026-02-07T19:30:39Z
- **Tasks:** 2
- **Files modified:** 1

## Accomplishments
- Deploy command now creates PATH symlink to make dotconfigs globally accessible
- Project command detects CWD when no path argument provided
- Dotconfigs repo rejected as project target to prevent self-modification
- Both features respect CLI flags (dry-run, force) consistently

## Task Commits

Each task was committed atomically:

1. **Task 1: Add PATH symlink creation to deploy flow** - `73e575e` (feat) — *completed in prior session (07-04)*
2. **Task 2: Add smart project path detection to cmd_project** - `9792ab0` (feat)

## Files Created/Modified
- `dotconfigs` - Added `_create_path_symlink()` function and smart CWD detection in `cmd_project()`

## Decisions Made

**1. Prefer ~/.local/bin over /usr/local/bin**
- Rationale: ~/.local/bin doesn't require sudo and is on PATH for most modern Linux/macOS setups. /usr/local/bin is traditional fallback.

**2. Use -ef test for same directory check**
- Rationale: More robust than string comparison (handles symlinks and relative paths correctly). POSIX-compatible.

**3. Default to 'yes' on CWD confirmation**
- Rationale: Optimistic UX - if user runs from a project repo, they likely want to use it. Easy to decline if wrong.

## Deviations from Plan

### Work Completed Early

**1. Task 1: PATH symlink creation**
- **Completed in:** 73e575e (docs(07-04): rewrite README with plugin architecture)
- **Issue:** Task 1 work was implemented during 07-04 README documentation session
- **Impact:** Function already exists and is tested. No additional work required for Task 1.
- **Verification:** Function exists, called in cmd_deploy, passes all verifications

---

**Total deviations:** 1 (work completed early)
**Impact on plan:** No functional impact. Task 1 was already done, Task 2 proceeded normally. Both tasks verified successful.

## Issues Encountered

None - Task 2 implementation proceeded smoothly. Task 1 was already complete.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

CLI usability improvements complete. Phase 7 ready for final plan (07-04: README documentation was already completed).

All phase 7 plans complete:
- 07-01: Shared infrastructure (colours, help, drift detection)
- 07-02: Status and list commands
- 07-03: Deploy enhancements (dry-run, force, summary)
- 07-04: README documentation (already complete)
- 07-05: CLI usability (PATH symlink, CWD detection)

Integration and Polish phase complete. v2.0 Plugin Architecture fully functional.

---
*Phase: 07-integration-and-polish*
*Completed: 2026-02-07*

## Self-Check: PASSED

All commits verified:
- 73e575e (Task 1)
- 9792ab0 (Task 2)

All files verified:
- dotconfigs
