---
phase: 10-hook-path-resolution
plan: 01
subsystem: infra
tags: [hooks, claude-code, deployment, path-resolution]

# Dependency graph
requires:
  - phase: v2.0
    provides: Plugin deployment system with settings.json assembly
provides:
  - Global hooks use absolute ~/.claude/hooks/ paths
  - Deploy-time path resolution via sed safety net
  - Template verification in test suite
affects: [11-hook-project-level-paths, project-init, any phase using hooks]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Deploy-time template variable resolution via sed
    - Global vs project hook path conventions (absolute vs relative)

key-files:
  created: []
  modified:
    - plugins/claude/templates/settings/settings-template.json
    - plugins/claude/deploy.sh
    - tests/test-project-configs.sh

key-decisions:
  - "Global hooks use ~/.claude/hooks/ (absolute) vs project hooks use .claude/hooks/ (relative)"
  - "Template contains final paths, sed provides safety net for drift"
  - "settings.json stays gitignored (user-editable assembled file)"

patterns-established:
  - "Hook path resolution: global absolute, project relative, resolved at deploy time"
  - "Template safety nets: sed cleanup catches variable drift in future edits"

# Metrics
duration: 2min
completed: 2026-02-10
---

# Phase 10 Plan 01: Hook Path Resolution Summary

**Global Claude hooks now use absolute ~/.claude/hooks/ paths instead of broken $CLAUDE_PROJECT_DIR variables, fixing hook execution from any project directory**

## Performance

- **Duration:** 2 min
- **Started:** 2026-02-10T16:48:30Z
- **Completed:** 2026-02-10T16:50:11Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Fixed global hook paths to use ~/.claude/hooks/ absolute references
- Added deploy-time sed safety net to catch template variable drift
- Extended test suite with global template assertion
- All 39 tests passing

## Task Commits

Each task was committed atomically:

1. **Task 1: Fix template and deploy-time path resolution** - `f9c071d` (fix)
2. **Task 2: Regenerate deployed settings.json and update tests** - `e70554e` (test)

## Files Created/Modified
- `plugins/claude/templates/settings/settings-template.json` - Changed hook paths from $CLAUDE_PROJECT_DIR/plugins/claude/hooks/ to ~/.claude/hooks/
- `plugins/claude/deploy.sh` - Added sed pass in _claude_assemble_settings() to resolve any remaining template variables
- `tests/test-project-configs.sh` - Added global template assertion verifying no $CLAUDE_PROJECT_DIR references

## Decisions Made

**Template vs runtime resolution:**
- Template contains final paths (not variables) for global case
- Sed provides safety net against drift if template accidentally edited with variables
- This makes template human-readable and avoids runtime variable expansion complexity

**Global vs project path conventions:**
- Global: ~/.claude/hooks/ (absolute) - works from any directory
- Project: .claude/hooks/ (relative) - resolves from project root
- Kept hooks.json unchanged (already correct with .claude/hooks/ relative paths)

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

**Gitignored settings.json:**
- Discovered settings.json is gitignored (correct - it's user-editable assembled file)
- Applied sed fix directly to existing file, verified in tests
- Template fix is what matters for future deployments

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Ready for Phase 11 (project-level hook path handling):
- Global hook path bug fixed
- Path resolution pattern established (absolute vs relative)
- Test coverage in place for template validation

Blocker removed:
- Global hooks now fire correctly when Claude runs outside dotconfigs repo
- $CLAUDE_PROJECT_DIR no longer appears in any deployed global settings

---
*Phase: 10-hook-path-resolution*
*Completed: 2026-02-10*

## Self-Check: PASSED
