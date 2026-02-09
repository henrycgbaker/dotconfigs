---
phase: 09-config-ux-redesign
plan: 05
subsystem: cli-ux
tags: [wizard, provenance, badges, colours, deploy, settings-assembly, git-exclusion]

# Dependency graph
requires:
  - phase: 09-02
    provides: "Colour badge helpers and wizard functions for G/L provenance"
  - phase: 09-03
    provides: "Claude global-configs wizard with opt-in model"
  - phase: 09-04
    provides: "Git wizard with 4-category opt-in model"
provides:
  - "G/L provenance indicators in project-configs wizards"
  - "CLAUDE.md exclusion applied during deploy"
  - "Settings.json assembly with language rule selection"
  - "Select loop eliminated from claude project.sh"
affects: [v2.0-final, user-acceptance-testing]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "G/L provenance display pattern for project-configs wizards"
    - "Settings.json assembly model with language rule selection"
    - "CLAUDE.md exclusion via deploy command"

key-files:
  created: []
  modified:
    - plugins/claude/deploy.sh
    - plugins/claude/project.sh
    - plugins/git/project.sh

key-decisions:
  - "Settings.json assembled from templates during deploy (not wizard)"
  - "CLAUDE.md exclusion reads config from .env and applies during deploy"
  - "Project-configs wizards show global values as reference with [G] badges"
  - "Local overrides displayed with [L] badges in green"
  - "Select loop replaced with read-based numbered prompt"

patterns-established:
  - "G/L provenance pattern: Show global config with [G] badge before prompting for override"
  - "Summary provenance: Final summary shows [G] or [L] for each config item"
  - "Assembly-then-link: Build settings.json from templates, then symlink"

# Metrics
duration: 3min
completed: 2026-02-09
---

# Phase 09 Plan 05: Config UX Redesign Summary

**Project-configs wizards with G/L provenance indicators, CLAUDE.md exclusion during deploy, and settings.json assembly with language rule selection**

## Performance

- **Duration:** 3 min
- **Started:** 2026-02-09T13:24:50Z
- **Completed:** 2026-02-09T13:28:21Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- G/L provenance indicators in both project-configs wizards (Claude and Git)
- CLAUDE.md exclusion applied during deploy command
- Settings.json assembled from base + language templates (Python/Node)
- Last select loop eliminated from claude project.sh

## Task Commits

Each task was committed atomically:

1. **Task 1: Add CLAUDE.md exclusion to deploy + settings.json language assembly** - `cae6bea` (feat)
2. **Task 2: Add G/L indicators to project-configs wizards + fix select loop** - `98112e6` (feat)

## Files Created/Modified
- `plugins/claude/deploy.sh` - Added `_claude_apply_md_exclusion()` and `_claude_assemble_settings()` functions
- `plugins/claude/project.sh` - Added G/L badges, CLAUDE.md exclusion step, replaced select loop, enhanced summary
- `plugins/git/project.sh` - Added G/L badges for identity and hooks, enhanced summary with provenance

## Decisions Made

**Settings.json assembly timing:**
- Decided to assemble during deploy (not during setup wizard)
- Reads CLAUDE_SETTINGS_PYTHON and CLAUDE_SETTINGS_NODE from .env
- Builds root settings.json from templates, then symlinks to deploy target
- Assembly order: base.json + python.json (if enabled) + node.json (if enabled) + hooks.json (if hooks enabled)

**CLAUDE.md exclusion implementation:**
- Applied during deploy command (not per-project)
- Reads CLAUDE_MD_EXCLUDE_GLOBAL and CLAUDE_MD_EXCLUDE_PATTERN from .env
- Writes patterns to .git/info/exclude of dotconfigs repo
- Dry-run mode supported

**G/L indicator display pattern:**
- Show global config with [G] badge in cyan as reference before prompting
- Show local overrides with [L] badge in green after creation
- Summary shows provenance for all configs (Global or Local)
- Works for settings, hooks, identity, and CLAUDE.md

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

Phase 9 complete (5/5 plans). All success criteria met:
- ✓ CLAUDE.md exclusion applied during deploy
- ✓ G/L provenance indicators in both project-configs wizards
- ✓ Last select loop (claude project.sh) replaced
- ✓ Settings.json assembled with language rules
- ✓ Summary shows provenance for all configs

Ready for:
- v2.0 final integration testing
- User acceptance testing (UAT)
- v2.0 release

Potential follow-up work:
- Test CLAUDE.md exclusion with various pattern configurations
- Test settings.json assembly with different language combinations
- Verify G/L indicators display correctly in both TTY and non-TTY contexts

---
*Phase: 09-config-ux-redesign*
*Completed: 2026-02-09*

## Self-Check: PASSED
