---
phase: 03-settings-hooks-deploy-skills
plan: 03
subsystem: git-hooks
tags: [bash, git-hooks, conventional-commits, ruff]

# Dependency graph
requires:
  - phase: 01-foundational-dev-environment
    provides: Git workflow conventions and hook infrastructure
provides:
  - Config-driven git hooks via .claude/hooks.conf
  - commit-msg hook validates conventional commits and blocks AI attribution
  - pre-commit hook does branch protection and Ruff formatting
  - Hooks work globally via core.hooksPath with per-project config
affects: [deployment, hook-deployment, global-setup]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Config-driven hooks via sourced .claude/hooks.conf"
    - "Squash merge detection to skip protection during merge"
    - "Three-tier branch protection: off/warn/block"

key-files:
  created: []
  modified:
    - githooks/commit-msg
    - githooks/pre-commit

key-decisions:
  - "Moved commit message validation from pre-commit to commit-msg hook (fixes COMMIT_EDITMSG timing bug)"
  - "Removed hardcoded identity check (git identity configured at deploy time, not enforced by hooks)"
  - "Branch protection defaults to 'warn' (configurable to 'block' or 'off')"
  - "AI attribution blocking always enforced (cannot be disabled via config)"

patterns-established:
  - "Hook config loading pattern: source .claude/hooks.conf if exists, fallback to sensible defaults"
  - "Squash merge detection via .git/SQUASH_MSG file or GIT_MERGE_SQUASH env var"

# Metrics
duration: 1min
completed: 2026-02-06
---

# Phase 3 Plan 03: Config-Driven Git Hooks Summary

**Git hooks refactored to config-driven architecture with conventional commit validation in commit-msg, branch protection in pre-commit, and COMMIT_EDITMSG timing bug fixed**

## Performance

- **Duration:** 1 min
- **Started:** 2026-02-06T23:36:12Z
- **Completed:** 2026-02-06T23:37:27Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Commit message validation moved to commit-msg hook (fixes timing bug where pre-commit read stale COMMIT_EDITMSG)
- Both hooks now config-driven via .claude/hooks.conf with sensible defaults
- Removed hardcoded identity check from pre-commit (git identity configured at deploy time)
- Branch protection with three modes: warn (default), block, off
- AI attribution blocking always enforced in commit-msg (cannot be disabled)
- Removed dead agent sync code

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor commit-msg hook with conventional commit validation** - `07cf08b` (refactor)
2. **Task 2: Refactor pre-commit hook to config-driven branch protection + Ruff** - `c5c7966` (refactor)

## Files Created/Modified
- `githooks/commit-msg` - Validates conventional commits (config-driven, main only) + blocks AI attribution (always)
- `githooks/pre-commit` - Branch protection (warn/block/off) + Ruff formatting (config-driven)

## Decisions Made

1. **Commit message validation moved to commit-msg hook**
   - Rationale: Pre-commit hook reads COMMIT_EDITMSG before git populates it, causing timing bugs. commit-msg receives message file as $1 parameter.

2. **Removed hardcoded identity check**
   - Rationale: Git identity configured at global deploy time via setup.sh, not enforced per-commit. Reduces coupling between hook and user identity.

3. **Branch protection defaults to 'warn'**
   - Rationale: Gentle nudge toward workflow best practices without blocking users who occasionally need direct main commits.

4. **AI attribution blocking always enforced**
   - Rationale: Core requirement for code ownership - cannot be disabled via project config.

5. **Removed agent sync code**
   - Rationale: Already disabled/commented out, removed entirely to reduce maintenance surface.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - hooks deployed globally during setup.sh execution. Projects can optionally create `.claude/hooks.conf` to override defaults:

```bash
# .claude/hooks.conf example
BRANCH_PROTECTION=block      # warn | block | off
CONVENTIONAL_COMMITS=false   # true | false
RUFF_ENABLED=false           # true | false
```

## Next Phase Readiness

- Git hooks ready for global deployment via core.hooksPath
- Hooks work across all projects with per-project configuration
- Next: Deploy hooks via setup.sh with git config core.hooksPath

**Blocker resolved:** COMMIT_EDITMSG timing bug fixed by moving validation to commit-msg hook.

## Self-Check: PASSED

All key files and commits verified.

---
*Phase: 03-settings-hooks-deploy-skills*
*Completed: 2026-02-06*
